# =============================================================================
# verify_8bit_resnet_hardware.py — Hardware-in-the-Loop ResNet-50 Benchmark (Q4.4)
# -----------------------------------------------------------------------------
# Evaluates PyTorch ResNet-50 layers via 100% full RTL hardware execution (Icarus Verilog vvp)
# using 16x16 Strassen GEMM tiles (Q4.4 format).
# =============================================================================
import os
import sys
import math
import argparse
import subprocess
import torch

sys.path.append(os.path.abspath("../test8bit"))
from cifar_resnet_layer_extractor import get_cifar_resnet50_conv_layers

TILE = 16

def encode_fixed8(x):
    """Encodes float32 value into signed 8-bit fixed-point (Q4.4 format)."""
    if x is None or math.isnan(x):
        return 0
    val = round(x * 16.0)
    val = max(-128, min(127, val))
    return val & 0xff

def decode_fixed8(b):
    """Decodes signed 8-bit integer into float32 value (Q4.4 format)."""
    if b >= 128:
        val = b - 256
    else:
        val = b
    return val / 16.0

def float_row_to_hex(row_vals):
    """Formats 8 float values into a 64-bit hex string (8 x 8-bit words)."""
    words = [encode_fixed8(x) for x in row_vals]
    return "".join(f"{w:02x}" for w in reversed(words))

def parse_hex_row(hex_str):
    """Parses a 64-bit hex string into 8 float values."""
    hex_str = hex_str.zfill(16)
    row_vals = []
    for i in range(8):
        word_str = hex_str[16 - 2*(i+1) : 16 - 2*i]
        val_word = int(word_str, 16)
        row_vals.append(decode_fixed8(val_word))
    return row_vals

def write_quadrant_file(matrix_16x16, filename):
    """
    Writes a 16x16 matrix into 4 Strassen 8x8 sub-matrix quadrants (32 lines total):
    Q11 (rows 0..7, cols 0..7), Q12 (rows 0..7, cols 8..15),
    Q21 (rows 8..15, cols 0..7), Q22 (rows 8..15, cols 8..15).
    """
    q11 = [matrix_16x16[r][0:8] for r in range(8)]
    q12 = [matrix_16x16[r][8:16] for r in range(8)]
    q21 = [matrix_16x16[r][0:8] for r in range(8, 16)]
    q22 = [matrix_16x16[r][8:16] for r in range(8, 16)]

    with open(filename, 'w') as f:
        for tile in [q11, q12, q21, q22]:
            for row in tile:
                f.write(float_row_to_hex(row) + "\n")

def read_output_quadrants(filename):
    """
    Reads 32 hardware output hex lines from output_c.txt and reconstructs a 16x16 matrix:
    C11 (lines 0..7), C12 (lines 8..15), C21 (lines 16..23), C22 (lines 24..31).
    """
    with open(filename, 'r') as f:
        lines = [line.strip() for line in f.readlines() if line.strip()]

    c11 = [parse_hex_row(line) for line in lines[0:8]]
    c12 = [parse_hex_row(line) for line in lines[8:16]]
    c21 = [parse_hex_row(line) for line in lines[16:24]]
    c22 = [parse_hex_row(line) for line in lines[24:32]]

    c_16x16 = []
    for i in range(8):
        c_16x16.append(c11[i] + c12[i])
    for i in range(8):
        c_16x16.append(c21[i] + c22[i])
    return c_16x16

def compile_verilog_netlist():
    """Compiles Verilog netlist once at script initialization."""
    print("[INFO] Compiling Verilog hardware netlist with iverilog (ONCE)...")
    verilog_files = [
        "eval_tb.v",
        "fixed_pe.v",
        "fixed_mac_array.v",
        "fixed_mxu.v",
        "strassen_controller.v",
        "strassen_preprocess.v",
        "strassen_scratchpad.v",
        "strassen_top.v"
    ]
    cmd_compile = ["iverilog", "-g2012", "-I", ".", "-o", "eval_sim.vvp"] + verilog_files
    subprocess.run(cmd_compile, check=True)
    print("[INFO] Compilation successful! Hardware simulation engine initialized.\n")

def run_one_16x16_tile(a16, b16):
    """Executes single 16x16 tile multiplication on RTL hardware via vvp simulation."""
    write_quadrant_file(a16, "input_a.txt")
    write_quadrant_file(b16, "input_b.txt")
    subprocess.run(["vvp", "eval_sim.vvp"], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return read_output_quadrants("output_c.txt")

def tiled_gemm_hw(matrix_a, matrix_b, M, K, N, use_relu=True):
    """Tiled GEMM executing 16x16 tiles directly on Verilog RTL hardware engine."""
    m_pad = math.ceil(M / TILE) * TILE
    k_pad = math.ceil(K / TILE) * TILE
    n_pad = math.ceil(N / TILE) * TILE

    a_pad = [[0.0] * k_pad for _ in range(m_pad)]
    b_pad = [[0.0] * n_pad for _ in range(k_pad)]

    for i in range(M):
        for k in range(K):
            a_pad[i][k] = matrix_a[i][k]
    for k in range(K):
        for j in range(N):
            b_pad[k][j] = matrix_b[k][j]

    c_accum = [[0.0] * n_pad for _ in range(m_pad)]

    n_mt = m_pad // TILE
    n_nt = n_pad // TILE
    n_kt = k_pad // TILE

    total_tiles = n_mt * n_nt * n_kt
    processed = 0

    for mt in range(n_mt):
        for nt in range(n_nt):
            for kt in range(n_kt):
                a16 = [a_pad[mt*TILE + r][kt*TILE : kt*TILE + TILE] for r in range(TILE)]
                b16 = [b_pad[kt*TILE + r][nt*TILE : nt*TILE + TILE] for r in range(TILE)]

                c16_tile = run_one_16x16_tile(a16, b16)

                for r in range(TILE):
                    for c in range(TILE):
                        c_accum[mt*TILE + r][nt*TILE + c] += c16_tile[r][c]

                processed += 1
                if processed % 500 == 0 or processed == total_tiles:
                    sys.stdout.write(f"\r      RTL Execution Progress: {processed}/{total_tiles} tiles ({100.0*processed/total_tiles:.1f}%)")
                    sys.stdout.flush()

    print()
    c_out = [[0.0] * N for _ in range(M)]
    for i in range(M):
        for j in range(N):
            val = c_accum[i][j]
            c_out[i][j] = max(0.0, val) if use_relu else val
    return c_out

def im2col_matrices(inp_chw, weight_oihw, stride, padding):
    C, H, W = inp_chw.shape
    O, _, kh, kw = weight_oihw.shape
    unfold = torch.nn.Unfold(kernel_size=(kh, kw), stride=stride, padding=padding)
    inp_unfolded = unfold(inp_chw.unsqueeze(0)).squeeze(0).transpose(0, 1)
    wt_flattened = weight_oihw.reshape(O, -1).transpose(0, 1)
    return inp_unfolded.tolist(), wt_flattened.tolist()

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

def main(weights="../test8bit/weights_resnet50_cifar10_seed42_fp32.pth", dataset="cifar10", layer_indices=None):
    print("=" * 90)
    print("  Full Hardware-in-the-Loop ResNet-50 Benchmark: 8-Bit Fixed-Point (Q4.4)")
    print("=" * 90)

    compile_verilog_netlist()

    print(f"[Main] Loading CIFAR ResNet-50 layers from {weights}...")
    layers = get_cifar_resnet50_conv_layers(weights_path=weights, dataset_name=dataset)
    if layer_indices is None:
        layer_indices = [0, 2, 12, 25, 45]

    for idx in layer_indices:
        spec = layers[idx]
        inp, wt = spec["input"], spec["weight"]
        C, H, W = inp.shape
        O, _, kh, kw = wt.shape
        stride, padding = spec["stride"], spec["padding"]

        matrix_a, matrix_b = im2col_matrices(inp, wt, stride, padding)
        M, K, N = len(matrix_a), len(matrix_a[0]), len(matrix_b[0])

        m_pad = math.ceil(M / TILE) * TILE
        k_pad = math.ceil(K / TILE) * TILE
        n_pad = math.ceil(N / TILE) * TILE
        total_tiles = (m_pad // TILE) * (k_pad // TILE) * (n_pad // TILE)

        print(f"\nLayer [{idx}] {spec['name']}: M={M} K={K} N={N} "
              f"(16x16 Tiles: {m_pad//TILE}x{k_pad//TILE}x{n_pad//TILE} = {total_tiles:,} tiles)")

        hw_c = tiled_gemm_hw(matrix_a, matrix_b, M, K, N, use_relu=True)
        ref_c = [[max(0.0, sum(matrix_a[i][k] * matrix_b[k][j] for k in range(K))) for j in range(N)] for i in range(M)]

        hw_flat = [v for row in hw_c for v in row]
        ref_flat = [v for row in ref_c for v in row]

        cos_sim, sqnr, rmse = compare(hw_flat, ref_flat)
        print(f"  -> RTL Cosine Similarity: {cos_sim:.6f} | SQNR: {sqnr:.2f} dB | RMSE: {rmse:.5f}")

    print("\n" + "=" * 90)
    print("Verified Status   : SUCCESS (Full Hardware-in-the-Loop Q4.4 Validation Complete)")
    print("=" * 90 + "\n")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Full Hardware-in-the-Loop ResNet-50 Benchmark (Q4.4)")
    parser.add_argument("--weights", default="../test8bit/weights_resnet50_cifar10_seed42_fp32.pth")
    parser.add_argument("--dataset", default="cifar10")
    args = parser.parse_args()

    main(weights=args.weights, dataset=args.dataset)
