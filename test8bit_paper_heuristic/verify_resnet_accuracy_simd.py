# =============================================================================
# verify_resnet_accuracy_simd.py — SIMD ResNet Accuracy Validation Tool
# Configured for 6-way 4-bit SIMD mode (triple-packed multipliers)
# =============================================================================
import os
import math
import random
import subprocess
import bisect
from dla_compiler import DLACompiler

# -----------------------------------------------------------------------------
# 1. 4-bit Posit Mapping (SIMD mode)
# -----------------------------------------------------------------------------
posit4_val_map = {
    0: 0.0,
    1: 0.0625,
    2: 0.125,
    3: 0.25,
    4: 0.5,
    5: 1.0,
    6: 2.0,
    7: 4.0,
    8: float('nan'),
    9: -4.0,
    10: -2.0,
    11: -1.0,
    12: -0.5,
    13: -0.25,
    14: -0.125,
    15: -0.0625
}

def encode_posit4(x):
    if x is None or math.isnan(x): return 8
    best_key = 0
    min_err = float('inf')
    for key, val in posit4_val_map.items():
        if key == 8: continue
        err = abs(x - val)
        if err < min_err:
            min_err = err
            best_key = key
    return best_key

def pack_hex_row_4b(rows):
    # rows is a list of 6 channels, each channel is a list of 8 floats
    packed_words = []
    for k in range(8):
        # 6 channels of 4-bit posits
        ch_p = [encode_posit4(rows[c][k]) for c in range(6)]
        byte1 = (ch_p[1] << 4) | ch_p[0] # Channel 1 High / Low
        byte2 = (ch_p[3] << 4) | ch_p[2] # Channel 2 High / Low
        byte3 = (ch_p[5] << 4) | ch_p[4] # Channel 3 High / Low
        packed_val = (byte3 << 16) | (byte2 << 8) | byte1
        packed_words.append(packed_val)
    return "".join(f"{val:06x}" for val in reversed(packed_words))

def parse_hex_row_4b(hex_str):
    hex_str = hex_str.strip().zfill(48)
    rows_out = [[] for _ in range(6)]
    for i in range(8):
        word_str = hex_str[48 - 6*(i+1) : 48 - 6*i]
        val_word = int(word_str, 16)
        
        b0 = val_word & 0xF
        b1 = (val_word >> 4) & 0xF
        b2 = (val_word >> 8) & 0xF
        b3 = (val_word >> 12) & 0xF
        b4 = (val_word >> 16) & 0xF
        b5 = (val_word >> 20) & 0xF
        
        rows_out[0].append(posit4_val_map.get(b0, 0.0))
        rows_out[1].append(posit4_val_map.get(b1, 0.0))
        rows_out[2].append(posit4_val_map.get(b2, 0.0))
        rows_out[3].append(posit4_val_map.get(b3, 0.0))
        rows_out[4].append(posit4_val_map.get(b4, 0.0))
        rows_out[5].append(posit4_val_map.get(b5, 0.0))
    return rows_out

# -----------------------------------------------------------------------------
# 2. Convolution Layer Specifications & Reference implementation
# -----------------------------------------------------------------------------
def run_conv_ref(input_data, weights, stride=1, padding=1, use_relu=False):
    C, H, W = len(input_data), len(input_data[0]), len(input_data[0][0])
    out_channels = len(weights)
    KH, KW = len(weights[0][0]), len(weights[0][0][0])
    
    H_padded = H + 2 * padding
    W_padded = W + 2 * padding
    
    h_out = (H_padded - KH) // stride + 1
    w_out = (W_padded - KW) // stride + 1
    
    act_padded = [[[0.0 for _ in range(W_padded)] for _ in range(H_padded)] for _ in range(C)]
    for c in range(C):
        for y in range(H):
            for x in range(W):
                act_padded[c][y + padding][x + padding] = input_data[c][y][x]
                
    out = [[[0.0 for _ in range(w_out)] for _ in range(h_out)] for _ in range(out_channels)]
    for m in range(out_channels):
        for y in range(h_out):
            for x in range(w_out):
                val = 0.0
                for c in range(C):
                    for ky in range(KH):
                        for kx in range(KW):
                            val += act_padded[c][y*stride + ky][x*stride + kx] * weights[m][c][ky][kx]
                if use_relu:
                    out[m][y][x] = max(0.0, val)
                else:
                    out[m][y][x] = val
    return out, act_padded

# -----------------------------------------------------------------------------
# 3. Main Validation Harness (Simulating 6 parallel jobs)
# -----------------------------------------------------------------------------
def run_validation():
    print("="*80)
    print("  ResNet End-to-End Accuracy Validation: 6-Way 4-Bit SIMD Mode")
    print("="*80)
    
    # Layer settings (64x64 mapped matrix multiplication)
    C, H, W = 7, 8, 8
    KH, KW = 3, 3
    stride = 1
    padding = 1
    out_channels = 64
    use_relu = False  # Disabled to expose unmasked quantization noise floor
    
    h_out = (H + 2 * padding - KH) // stride + 1
    w_out = (W + 2 * padding - KW) // stride + 1
    
    # Create 6 independent sets of inputs/weights for 6 parallel jobs
    random.seed(456)
    
    inputs = []
    weights_list = []
    ref_outputs = []
    act_padded_list = []
    
    for job in range(6):
        inp = [[[random.random() for _ in range(W)] for _ in range(H)] for _ in range(C)]
        scale = math.sqrt(2.0 / (KH * KW * C))
        wt = [[[[random.normalvariate(0.0, scale) for _ in range(KW)] for _ in range(KH)] for _ in range(C)] for _ in range(out_channels)]
        
        ref_out, act_pad = run_conv_ref(inp, wt, stride, padding, use_relu)
        
        inputs.append(inp)
        weights_list.append(wt)
        ref_outputs.append(ref_out)
        act_padded_list.append(act_pad)

    # -------------------------------------------------------------------------
    # im2col Matrix Mapping & Tiling (64x64 matrix size for each job)
    # -------------------------------------------------------------------------
    matrices_a = []
    matrices_b = []
    
    for job in range(6):
        matrix_a = [[0.0 for _ in range(64)] for _ in range(64)]
        for y in range(h_out):
            for x in range(w_out):
                row_idx = y * w_out + x
                col_idx = 0
                for c in range(C):
                    for ky in range(KH):
                        for kx in range(KW):
                            matrix_a[row_idx][col_idx] = act_padded_list[job][c][y*stride + ky][x*stride + kx]
                            col_idx += 1
        
        matrix_b = [[0.0 for _ in range(64)] for _ in range(64)]
        for m in range(out_channels):
            row_idx = 0
            for c in range(C):
                for ky in range(KH):
                    for kx in range(KW):
                        matrix_b[row_idx][m] = weights_list[job][m][c][ky][kx]
                        row_idx += 1
                        
        matrices_a.append(matrix_a)
        matrices_b.append(matrix_b)

    # -------------------------------------------------------------------------
    # Write input files (6-channel packed format) - 16 tiles * 32 rows/tile = 512 rows
    # -------------------------------------------------------------------------
    print("[DEBUG] Quantizing and packing matrices for 6 concurrent jobs...")
    
    with open("input_a.txt", "w") as f:
        for tr in range(4):
            for tc in range(4):
                tiles = [[row[tc*16 : (tc+1)*16] for row in matrices_a[job][tr*16 : (tr+1)*16]] for job in range(6)]
                
                A11 = [[r[0:8] for r in tiles[job][0:8]] for job in range(6)]
                A12 = [[r[8:16] for r in tiles[job][0:8]] for job in range(6)]
                A21 = [[r[0:8] for r in tiles[job][8:16]] for job in range(6)]
                A22 = [[r[8:16] for r in tiles[job][8:16]] for job in range(6)]

                for q_idx in range(4):
                    quads_ch = [[A11[job], A12[job], A21[job], A22[job]][q_idx] for job in range(6)]
                    for r in range(8):
                        row_elements = [quads_ch[job][r] for job in range(6)]
                        f.write(pack_hex_row_4b(row_elements) + "\n")
            
    with open("input_b.txt", "w") as f:
        for tr in range(4):
            for tc in range(4):
                tiles = [[row[tc*16 : (tc+1)*16] for row in matrices_b[job][tr*16 : (tr+1)*16]] for job in range(6)]
                
                B11 = [[r[0:8] for r in tiles[job][0:8]] for job in range(6)]
                B12 = [[r[8:16] for r in tiles[job][0:8]] for job in range(6)]
                B21 = [[r[0:8] for r in tiles[job][8:16]] for job in range(6)]
                B22 = [[r[8:16] for r in tiles[job][8:16]] for job in range(6)]

                for q_idx in range(4):
                    quads_ch = [[B11[job], B12[job], B21[job], B22[job]][q_idx] for job in range(6)]
                    for r in range(8):
                        row_elements = [quads_ch[job][r] for job in range(6)]
                        f.write(pack_hex_row_4b(row_elements) + "\n")

    # -------------------------------------------------------------------------
    # 6. Compile DLA Program Instructions (simd_mode = True)
    # -------------------------------------------------------------------------
    print("[DEBUG] Compiling DLA instructions for Conv Layer (SIMD mode)...")
    compiler = DLACompiler()
    prog_text, prog_hex = compiler.compile_conv_layer(
        h=H, w=W, c=C, kh=KH, kw=KW,
        stride=stride, padding=padding,
        out_channels=out_channels, use_relu=use_relu, simd_mode=True
    )
    with open("dla_program.hex", "w") as f:
        f.write(prog_hex)

    # -------------------------------------------------------------------------
    # 7. Run DLA hardware simulation in iverilog
    # -------------------------------------------------------------------------
    print("[DEBUG] Compiling Verilog hardware simulation using iverilog...")
    src_files = [
        "dla_tb.v", "dla_axi_wrapper.v", "dla_dma_controller.v", "dla_top.v",
        "dla_controller.v", "dla_sram.v", "vector_activation.v", "vector_add.v",
        "strassen_top.v", "strassen_preprocess.v", "strassen_scratchpad.v",
        "strassen_controller.v", "posit_mxu.v", "posit_mac_array.v",
        "posit_pe.v", "posit_mult.v", "posit_add.v", "posit_add_comb.v",
        "posit_decode.v", "posit_encode.v", "quire_acc.v",
        "posit_add_simd.v", "fixed_to_decoded_conv.v",
        "fixed_to_posit_conv_4b.v", "fixed_to_posit_conv_8b.v",
        "posit_to_fixed_conv_4b.v", "posit_to_fixed_conv_8b.v",
        "posit_dsp_packing.v", "dsp48e2_sim_model.v"
    ]
        
    cmd_compile = ["iverilog", "-g2012", "-DNUM_WORDS=512", "-I", ".", "-o", "dla_sim.vvp"] + src_files
    res_compile = subprocess.run(cmd_compile, capture_output=True, text=True)
    if res_compile.returncode != 0:
        print("[ERR] iverilog compilation failed:")
        print(res_compile.stderr)
        return
        
    print("[DEBUG] Running simulation...")
    res_run = subprocess.run(["vvp", "dla_sim.vvp"], capture_output=True, text=True)
    if res_run.returncode != 0:
        print("[ERR] vvp execution failed:")
        print(res_run.stderr)
        return
 
    # -------------------------------------------------------------------------
    # 8. Reconstruct and Parse output matrix from DRAM
    # -------------------------------------------------------------------------
    if not os.path.exists("dla_output_c.txt"):
        print("[ERR] DLA output file dla_output_c.txt not found!")
        return
        
    print("[DEBUG] Parsing output from dla_output_c.txt...")
    with open("dla_output_c.txt", "r") as f:
        out_lines = [line.strip() for line in f.readlines() if line.strip()]
        
    if len(out_lines) != 512:
        print(f"[ERR] Expected 512 lines in dla_output_c.txt, got {len(out_lines)}")
        return
        
    dla_matrix_c = [[[0.0 for _ in range(64)] for _ in range(64)] for _ in range(6)]
    for tr in range(4):
        for tc in range(4):
            tile_idx = tr * 4 + tc
            tile_lines = out_lines[tile_idx * 32 : (tile_idx + 1) * 32]
            
            C11_t = [parse_hex_row_4b(line) for line in tile_lines[0:8]]
            C12_t = [parse_hex_row_4b(line) for line in tile_lines[8:16]]
            C21_t = [parse_hex_row_4b(line) for line in tile_lines[16:24]]
            C22_t = [parse_hex_row_4b(line) for line in tile_lines[24:32]]
            
            for ch in range(6):
                C11_ch = [C11_t[r][ch] for r in range(8)]
                C12_ch = [C12_t[r][ch] for r in range(8)]
                C21_ch = [C21_t[r][ch] for r in range(8)]
                C22_ch = [C22_t[r][ch] for r in range(8)]
                
                tile_16x16 = []
                for r in range(8):
                    tile_16x16.append(C11_ch[r] + C12_ch[r])
                for r in range(8):
                    tile_16x16.append(C21_ch[r] + C22_ch[r])
                    
                for r in range(16):
                    for c in range(16):
                        dla_matrix_c[ch][tr*16 + r][tc*16 + c] = tile_16x16[r][c]
            
    # Extract output channels for the 8x8 image
    dla_outs = [[[[0.0 for _ in range(w_out)] for _ in range(h_out)] for _ in range(out_channels)] for _ in range(6)]
    for job in range(6):
        for y in range(h_out):
            for x in range(w_out):
                pixel_idx = y * w_out + x
                for m in range(out_channels):
                    dla_outs[job][m][y][x] = dla_matrix_c[job][pixel_idx][m]

    # -------------------------------------------------------------------------
    # 9. Perform Numerical Accuracy Comparison (For all 6 jobs)
    # -------------------------------------------------------------------------
    print("\n" + "="*80)
    print("                 6-WAY ACCURACY COMPARISON STATISTICS")
    print("="*80)
    
    for job in range(6):
        total_sq_error = 0.0
        total_elements = 0
        ref_dot_dla = 0.0
        ref_norm_sq = 0.0
        dla_norm_sq = 0.0
        
        for m in range(out_channels):
            for y in range(h_out):
                for x in range(w_out):
                    ref_val = ref_outputs[job][m][y][x]
                    dla_val = dla_outs[job][m][y][x]
                    
                    diff = ref_val - dla_val
                    total_sq_error += diff * diff
                    total_elements += 1
                    
                    ref_dot_dla += ref_val * dla_val
                    ref_norm_sq += ref_val * ref_val
                    dla_norm_sq += dla_val * dla_val

        mse = total_sq_error / total_elements
        rmse = math.sqrt(mse)
        
        if ref_norm_sq > 0.0 and dla_norm_sq > 0.0:
            cos_sim = ref_dot_dla / (math.sqrt(ref_norm_sq) * math.sqrt(dla_norm_sq))
        else:
            cos_sim = 1.0 if (ref_norm_sq == 0.0 and dla_norm_sq == 0.0) else 0.0
            
        sqnr = 10 * math.log10(ref_norm_sq / total_sq_error) if total_sq_error > 0 else float('inf')
            
        print(f"Job {job + 1} (4-bit SIMD)   -> Cosine Similarity: {cos_sim:.8f} | SQNR: {sqnr:.2f} dB | RMSE: {rmse:.5f}")

    print("="*80)

if __name__ == "__main__":
    run_validation()
