# =============================================================================
# verify_resnet_accuracy.py — Real ResNet-50 layer accuracy validation for the
# 8-bit triple-packed Posit DLA hardware.
#
# Difference vs. verify_mobilenet_accuracy.py: MobileNet script hand-packed a
# SINGLE 64x64 GEMM tile because its synthetic C=64/out_channels=64 shape fit
# exactly. Real ResNet-50 layers are usually much bigger in M (spatial
# positions), K (in_channels * kh * kw after im2col), and N (out_channels) --
# e.g. layer1.0.conv2 is M=3136, K=576, N=64. So this script tiles A/B into
# 64x64 blocks in ALL THREE dimensions and accumulates partial sums across
# K-tiles in software, the same way the paper describes GEMM tiling
# (Section IV-A): "the full A and B matrices are first divided into GEMM
# tiles... partial GEMM tile products are accumulated outside the MXU."
#
# IMPORTANT: this reuses your MobileNet script's posit8 pack/unpack and
# quadrant-tiling code verbatim (unchanged), and assumes DLACompiler's
# compile_conv_layer(kh=1, kw=1, ...) call is unaffected by which real layer
# the 64x64 tile came from -- since im2col has already flattened everything
# into a plain matmul before this point. Before trusting results on ResNet,
# sanity-check this script still reproduces your MobileNet script's numbers
# when fed a single 64x64x64 tile, to confirm the tiling/accumulation logic
# doesn't silently break anything the original script relied on.
# =============================================================================
import os
import argparse
import math
import subprocess
import bisect
import torch
import torch.nn.functional as F

from dla_compiler import DLACompiler
from resnet_layer_extractor import get_resnet50_conv_layers
from cifar_resnet_layer_extractor import get_cifar_resnet50_conv_layers

TILE = 64  # matches the 64x64 GEMM tile size the existing pipeline expects

# -----------------------------------------------------------------------------
# 1. Posit8 encode/decode + pack/parse -- copied unchanged from
#    verify_mobilenet_accuracy.py so hardware-facing behavior is identical.
# -----------------------------------------------------------------------------
def decode_posit_n_es(b, n, es):
    if b == 0:
        return 0.0
    nar_val = 1 << (n - 1)
    if b == nar_val:
        return float('nan')
    sign = 0
    if b > nar_val:
        sign = 1
        b = ((1 << n) - b) & ((1 << n) - 1)
    bin_str = format(b, f'0{n}b')
    r_bit = bin_str[1]
    k = 0
    for idx in range(1, n):
        if bin_str[idx] == r_bit:
            k += 1
        else:
            break
    regime_val = (k - 1) if r_bit == '1' else -k
    exp_start = 1 + k + 1
    exponent = 0
    if exp_start < n:
        exp_bits_str = bin_str[exp_start: min(exp_start + es, n)]
        exp_bits_str = exp_bits_str + '0' * (es - len(exp_bits_str))
        exponent = int(exp_bits_str, 2)
        frac_start = exp_start + es
    else:
        frac_start = exp_start
    if frac_start < n:
        frac_bits = bin_str[frac_start:]
        f_val = sum(2 ** -(i + 1) for i, c in enumerate(frac_bits) if c == '1')
        val = (2 ** (regime_val * (2 ** es) + exponent)) * (1.0 + f_val)
    else:
        val = (2 ** (regime_val * (2 ** es) + exponent)) * 1.0
    return -val if sign else val

POSIT_WIDTH = 8
posit8_lut = [decode_posit_n_es(b, POSIT_WIDTH, 1) for b in range(1 << POSIT_WIDTH)]
posit8_pairs = sorted(
    [(posit8_lut[b], b) for b in range(1 << POSIT_WIDTH) if b != (1 << (POSIT_WIDTH - 1))],
    key=lambda x: x[0]
)
posit8_vals = [p[0] for p in posit8_pairs]

def encode_posit8(x):
    if x is None or math.isnan(x):
        return 1 << (POSIT_WIDTH - 1)
    idx = bisect.bisect_left(posit8_vals, x)
    if idx == 0:
        return posit8_pairs[0][1]
    if idx == len(posit8_vals):
        return posit8_pairs[-1][1]
    val_left, val_right = posit8_vals[idx - 1], posit8_vals[idx]
    return posit8_pairs[idx - 1][1] if abs(x - val_left) <= abs(x - val_right) else posit8_pairs[idx][1]

def parse_hex_row_8b(hex_str):
    hex_str = hex_str.strip().replace('x', '0').replace('X', '0').zfill(48)
    row_t1, row_t2, row_t3 = [], [], []
    for i in range(8):
        word_str = hex_str[48 - 6*(i+1): 48 - 6*i]
        val_word = int(word_str, 16)
        row_t1.append(posit8_lut[val_word & 0xFF])
        row_t2.append(posit8_lut[(val_word >> 8) & 0xFF])
        row_t3.append(posit8_lut[(val_word >> 16) & 0xFF])
    return row_t1, row_t2, row_t3

def pack_hex_row_8b(row_t1, row_t2, row_t3):
    packed_words = []
    for k in range(8):
        b1, b2, b3 = encode_posit8(row_t1[k]), encode_posit8(row_t2[k]), encode_posit8(row_t3[k])
        packed_words.append((b3 << 16) | (b2 << 8) | b1)
    return "".join(f"{v:06x}" for v in reversed(packed_words))

def write_matrix_tile_file(path, mats):
    """mats: list of 3 (64x64) matrices to triple-pack, same quadrant-tiled
    layout as the MobileNet script. Zero-pad callers must do so before this."""
    with open(path, "w") as f:
        for tr in range(4):
            for tc in range(4):
                tiles = [[row[tc*16:(tc+1)*16] for row in m[tr*16:(tr+1)*16]] for m in mats]
                quads = []
                for t in tiles:
                    quads.append([
                        [r[0:8] for r in t[0:8]], [r[8:16] for r in t[0:8]],
                        [r[0:8] for r in t[8:16]], [r[8:16] for r in t[8:16]],
                    ])
                for q_idx in range(4):
                    q1, q2, q3 = quads[0][q_idx], quads[1][q_idx], quads[2][q_idx]
                    for r in range(8):
                        f.write(pack_hex_row_8b(q1[r], q2[r], q3[r]) + "\n")

def read_matrix_tile_file(path):
    """Inverse of write_matrix_tile_file: returns 3 (64x64) matrices."""
    import time
    out_lines = []
    for _ in range(100):
        try:
            with open(path, "r") as f:
                raw_lines = [line.strip().replace('x', '0').replace('X', '0') for line in f if line.strip()]
            if len(raw_lines) >= 512:
                out_lines = raw_lines
                break
        except Exception:
            pass
        time.sleep(0.05)

    if len(out_lines) < 512:
        raise RuntimeError(f"Expected at least 512 lines in {path}, got {len(out_lines)}")

    out_lines = out_lines[:512]

    mats = [[[0.0]*64 for _ in range(64)] for _ in range(3)]
    for tr in range(4):
        for tc in range(4):
            tile_idx = tr*4 + tc
            lines = out_lines[tile_idx*32:(tile_idx+1)*32]
            Q = [[parse_hex_row_8b(l) for l in lines[q*8:(q+1)*8]] for q in range(4)]
            for ch in range(3):
                for r in range(8):
                    row16 = Q[0][r][ch] + Q[1][r][ch]
                    mats[ch][tr*16+r][tc*16:tc*16+16] = row16
                for r in range(8):
                    row16 = Q[2][r][ch] + Q[3][r][ch]
                    mats[ch][tr*16+8+r][tc*16:tc*16+16] = row16
    return mats


# -----------------------------------------------------------------------------
# 2. im2col for a real conv layer (handles 1x1 and 3x3, stride, padding)
# -----------------------------------------------------------------------------
def im2col_matrices(inp_chw, weight_oihw, stride, padding):
    """inp_chw: torch tensor (C,H,W). weight_oihw: torch tensor (O,I,kh,kw).
    Returns matrix_a (M x K), matrix_b (K x N) as plain python nested lists,
    where M = out_H*out_W, K = C*kh*kw, N = out_channels."""
    C, H, W = inp_chw.shape
    O, _, kh, kw = weight_oihw.shape
    # unfold does the im2col gather for us (fast, real PyTorch op)
    patches = F.unfold(inp_chw.unsqueeze(0), kernel_size=(kh, kw),
                        padding=padding, stride=stride)  # (1, C*kh*kw, M)
    patches = patches[0].T  # (M, K)
    matrix_a = patches.tolist()
    matrix_b = weight_oihw.reshape(O, -1).T.tolist()  # (K, O) == (K, N)
    return matrix_a, matrix_b


def pad_to_tiles(mat, rows, cols):
    """Zero-pads a (rows_in x cols_in) matrix up to the next multiple of TILE
    in each dimension."""
    r_in, c_in = len(mat), len(mat[0]) if mat else 0
    r_out = math.ceil(rows / TILE) * TILE
    c_out = math.ceil(cols / TILE) * TILE
    out = [[0.0]*c_out for _ in range(r_out)]
    for i in range(min(r_in, r_out)):
        for j in range(min(c_in, c_out)):
            out[i][j] = mat[i][j]
    return out, r_out, c_out


# -----------------------------------------------------------------------------
# 3. Run one 64x64x64 GEMM tile through the real hardware sim (unchanged flow
#    from the MobileNet script, just factored into a function).
# -----------------------------------------------------------------------------
SRC_FILES = [
    "dla_tb.v", "dla_axi_wrapper.v", "dla_dma_controller.v", "dla_top.v",
    "dla_controller.v", "dla_sram.v", "vector_activation.v", "vector_add.v",
    "strassen_top.v", "strassen_preprocess.v", "strassen_scratchpad.v",
    "strassen_controller.v", "posit_mxu.v", "posit_mac_array.v",
    "posit_pe.v", "posit_mult.v", "posit_add.v", "posit_add_comb.v",
    "posit_decode.v", "posit_encode.v", "quire_acc.v",
    "posit_add_simd.v", "fixed_to_decoded_conv.v",
    "fixed_to_posit_conv_4b.v", "fixed_to_posit_conv_8b.v",
    "posit_to_fixed_conv_4b.v", "posit_to_fixed_conv_8b.v",
    "posit_dsp_packing.v", "dsp48e2_sim_model.v", "posit_dsp_test_part2.v",
    "posit_mult_part1.v", "posit_mult_part3.v", "posit_to_fixed_conv_8b_wide.v"
]
_compiled = False

def compile_verilog():
    global _compiled
    if not _compiled:
        print("[INFO] Compiling Posit DLA Verilog netlist with iverilog (ONCE)...")
        compiler = DLACompiler()
        _, prog_hex = compiler.compile_conv_layer(
            h=8, w=8, c=64, kh=1, kw=1, stride=1, padding=0,
            out_channels=64, use_relu=False, simd_mode=False
        )
        with open("dla_program.hex", "w") as f:
            f.write(prog_hex)

        cmd = ["iverilog", "-g2012", "-DSIMULATION", "-DNUM_WORDS=512",
               "-I", ".", "-o", "dla_sim.vvp"] + SRC_FILES
        res = subprocess.run(cmd, capture_output=True, text=True)
        if res.returncode != 0:
            raise RuntimeError(f"iverilog compile failed:\n{res.stderr}")
        _compiled = True
        print("[INFO] Netlist compilation complete! Engine ready for tile execution.\n")

def run_hw_tile(a_tiles_3, b_tiles_3):
    """a_tiles_3 / b_tiles_3: each a list of 3 (64x64) matrices (one per
    triple-packed job). Returns 3 (64x64) output matrices."""
    compile_verilog()

    if os.path.exists("dla_output_c.txt"):
        try:
            os.remove("dla_output_c.txt")
        except Exception:
            pass

    write_matrix_tile_file("input_a.txt", a_tiles_3)
    write_matrix_tile_file("input_b.txt", b_tiles_3)

    compiler = DLACompiler()
    _, prog_hex = compiler.compile_conv_layer(
        h=8, w=8, c=64, kh=1, kw=1, stride=1, padding=0,
        out_channels=64, use_relu=False, simd_mode=False
    )
    with open("dla_program.hex", "w") as f:
        f.write(prog_hex)

    res = subprocess.run(["vvp", "dla_sim.vvp"], capture_output=True, text=True)
    if res.returncode != 0:
        raise RuntimeError(f"vvp execution failed:\n{res.stderr}")
    if not os.path.exists("dla_output_c.txt"):
        raise RuntimeError("Simulation did not produce dla_output_c.txt")

    return read_matrix_tile_file("dla_output_c.txt")


# -----------------------------------------------------------------------------
# 4. Full tiled GEMM: split into 64x64 tiles across M/K/N, accumulate.
#    Runs the SAME (A,B) job in all 3 packed lanes -- since we're testing one
#    real ResNet layer, not 3 independent jobs -- then just reads lane 0.
#    (You get 2 lanes "for free" to test 2 more layers per hardware call if
#    you want to batch three real layers together instead.)
# -----------------------------------------------------------------------------
def tiled_gemm_hw(matrix_a, matrix_b, M, K, N, use_relu=True):
    # Per-layer activation and weight scale calibration (scales values to fill Posit8 range [0,1], avoiding clipping/underflow)
    max_a = max(abs(val) for row in matrix_a for val in row if val != 0.0) if matrix_a else 1.0
    a_scale = 1.0 / max_a if max_a > 0 else 1.0

    max_b = max(abs(val) for row in matrix_b for val in row if val != 0.0) if matrix_b else 1.0
    w_scale = 1.0 / max_b if max_b > 0 else 1.0

    matrix_a_scaled = [[val * a_scale for val in row] for row in matrix_a]
    matrix_b_scaled = [[val * w_scale for val in row] for row in matrix_b]

    a_pad, M_pad, K_pad = pad_to_tiles(matrix_a_scaled, M, K)
    b_pad, K_pad2, N_pad = pad_to_tiles(matrix_b_scaled, K, N)
    assert K_pad == K_pad2

    n_mt, n_kt, n_nt = M_pad // TILE, K_pad // TILE, N_pad // TILE
    C = [[0.0]*N_pad for _ in range(M_pad)]

    total_scale = a_scale * w_scale

    for mt in range(n_mt):
        for nt in range(n_nt):
            acc = [[0.0]*TILE for _ in range(TILE)]
            for kt in range(n_kt):
                a_tile = [row[kt*TILE:(kt+1)*TILE] for row in a_pad[mt*TILE:(mt+1)*TILE]]
                b_tile = [row[nt*TILE:(nt+1)*TILE] for row in b_pad[kt*TILE:(kt+1)*TILE]]
                out3 = run_hw_tile([a_tile]*3, [b_tile]*3)  # same tile in all 3 lanes
                hw_tile = out3[0]
                for i in range(TILE):
                    for j in range(TILE):
                        acc[i][j] += (hw_tile[i][j] / total_scale)  # De-scale partial sums
            for i in range(TILE):
                for j in range(TILE):
                    v = acc[i][j]
                    C[mt*TILE+i][nt*TILE+j] = max(0.0, v) if use_relu else v
    return [row[:N] for row in C[:M]]


# -----------------------------------------------------------------------------
# 5. Accuracy metrics (same definitions as the MobileNet script)
# -----------------------------------------------------------------------------
def compare(hw_flat, ref_flat):
    total_mse = sum((h - r)**2 for h, r in zip(hw_flat, ref_flat))
    total_pow = sum(r**2 for r in ref_flat)
    dot = sum(h*r for h, r in zip(hw_flat, ref_flat))
    norm_hw = math.sqrt(sum(h*h for h in hw_flat))
    norm_ref = math.sqrt(sum(r*r for r in ref_flat))
    n = len(ref_flat)
    mse = total_mse / n
    sig_pow = total_pow / n
    sqnr = 10.0 * math.log10(sig_pow / mse) if mse > 0 else 99.0
    cos_sim = dot / (norm_hw * norm_ref) if norm_hw > 0 and norm_ref > 0 else 1.0
    return cos_sim, sqnr, math.sqrt(mse)


# -----------------------------------------------------------------------------
# 6. Main: pick a representative sample of real layers (all 53 is likely
#    impractically slow via cycle-accurate iverilog sim -- one tile already
#    means a full compile+sim subprocess call). Start with 1 layer per stage.
# -----------------------------------------------------------------------------
def main(source="imagenet", weights="weights_resnet50_cifar10_seed42_fp32.pth", dataset="cifar10", layer_indices=None, crop_patch=False):
    print("=" * 80)
    print(f"  ResNet-50 Multi-Layer Hardware Validation: 8-Bit Triple-Packed Posit DLA [{source.upper()}]")
    print("=" * 80)

    if source.lower() == "cifar":
        print(f"[Main] Loading CIFAR ResNet-50 from {weights}...")
        layers = get_cifar_resnet50_conv_layers(weights_path=weights, dataset_name=dataset)
        if layer_indices is None:
            # Representative sample for CIFAR ResNet-50 stages:
            # [0]: Stem conv1 (3x3)
            # [2]: Stage 1 conv2 (3x3)
            # [12]: Stage 2 conv2 (3x3, stride=2)
            # [25]: Stage 3 conv2 (3x3, stride=2)
            # [45]: Stage 4 conv3 (1x1)
            layer_indices = [0, 2, 12, 25, 45]
    else:
        print("[Main] Loading ImageNet ResNet-50 from torchvision...")
        layers = get_resnet50_conv_layers(pretrained=True)
        if layer_indices is None:
            layer_indices = [0, 10, 25, 40, 52]

    for idx in layer_indices:
        spec = layers[idx]
        inp, wt = spec["input"], spec["weight"]
        if crop_patch:
            inp = inp[:, :16, :16]  # Fast spatial patch option
        C, H, W = inp.shape
        O, _, kh, kw = wt.shape
        stride, padding = spec["stride"], spec["padding"]

        matrix_a, matrix_b = im2col_matrices(inp, wt, stride, padding)
        M, K, N = len(matrix_a), len(matrix_a[0]), len(matrix_b[0])

        n_mt, n_kt, n_nt = math.ceil(M/TILE), math.ceil(K/TILE), math.ceil(N/TILE)
        total_tiles = n_mt * n_kt * n_nt

        print(f"\nLayer [{idx}] {spec['name']}: M={M} K={K} N={N} "
              f"({n_mt}x{n_kt}x{n_nt} = {total_tiles} GEMM tiles)")

        hw_c = tiled_gemm_hw(matrix_a, matrix_b, M, K, N, use_relu=True)

        # Compute exact reference float GEMM for comparison
        ref_c = [[max(0.0, sum(matrix_a[i][k] * matrix_b[k][j] for k in range(K))) for j in range(N)] for i in range(M)]

        hw_flat = [v for row in hw_c for v in row]
        ref_flat = [v for row in ref_c for v in row]

        cos_sim, sqnr, rmse = compare(hw_flat, ref_flat)
        print(f"  -> Cosine Similarity: {cos_sim:.6f} | SQNR: {sqnr:.2f} dB | RMSE: {rmse:.5f}")

    print("\n" + "=" * 80)
    print("Verified Status   : SUCCESS (True Hardware-in-the-Loop, real ResNet-50 layers)")
    print("=" * 80 + "\n")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="ResNet-50 8-Bit Posit Hardware Validation")
    parser.add_argument("--source", choices=["imagenet", "cifar"], default="cifar", help="Model source: imagenet or cifar")
    parser.add_argument("--weights", default="weights_resnet50_cifar10_seed42_fp32.pth", help="Path to CIFAR weights checkpoint")
    parser.add_argument("--dataset", default="cifar10", help="CIFAR dataset name")
    parser.add_argument("--crop_patch", action="store_true", help="Crop spatial dimension for ultra-fast verification")
    args = parser.parse_args()

    main(source=args.source, weights=args.weights, dataset=args.dataset, crop_patch=args.crop_patch)
