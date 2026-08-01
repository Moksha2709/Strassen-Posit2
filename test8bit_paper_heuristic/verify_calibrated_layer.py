import os
import math
import subprocess
import random

from verify_mobilenet_accuracy import (
    encode_posit8, pack_hex_row_8b, parse_hex_row_8b, decode_posit_n_es
)
from dla_compiler import DLACompiler

def main():
    print("=" * 80)
    print(" 3. END-TO-END LAYER SIMULATION WITH PER-TENSOR SCALE CALIBRATION")
    print("=" * 80)
    random.seed(42)
    H, W, C = 8, 8, 64
    out_channels = 64
    
    inputs, weights_list, ref_outputs, weight_scales = [], [], [], []
    for job in range(3):
        inp = [[[random.random() for _ in range(W)] for _ in range(H)] for _ in range(C)]
        scale_val = math.sqrt(2.0 / C)
        wt = [[[[random.normalvariate(0.0, scale_val)]] for _ in range(C)] for _ in range(out_channels)]
        
        # Scale weights so that MAC sum sum(A * W) stays within Posit8 dynamic range [-16, 16]
        max_wt = max(abs(wt[m][c][0][0]) for m in range(out_channels) for c in range(C))
        w_scale = (1.0 / (max_wt * math.sqrt(C))) if max_wt > 0 else 1.0
        
        # Scaled weights
        wt_scaled = [[[[wt[m][c][0][0] * w_scale]] for c in range(C)] for m in range(out_channels)]
        
        # Reference Float32 output
        out_ref = [[[max(0.0, sum(inp[c][y][x] * wt[m][c][0][0] for c in range(C))) for x in range(W)] for y in range(H)] for m in range(out_channels)]
        
        inputs.append(inp)
        weights_list.append(wt_scaled)
        ref_outputs.append(out_ref)
        weight_scales.append(w_scale)

    # Pack hardware input files
    q_a_all, q_b_all = [], []
    for job in range(3):
        mat_a = [[inputs[job][c][r // W][r % W] for c in range(C)] for r in range(64)]
        mat_b = [[weights_list[job][m][c][0][0] for m in range(out_channels)] for c in range(C)]
        
        # Quantize to Posit8
        q_a = [[encode_posit8(v) for v in row] for row in mat_a]
        q_b = [[encode_posit8(v) for v in row] for row in mat_b]
        q_a_all.append(q_a)
        q_b_all.append(q_b)

    with open("input_a.txt", "w") as f:
        for tr in range(4):
            for tc in range(4):
                t1 = [r[tc*16:(tc+1)*16] for r in q_a_all[0][tr*16:(tr+1)*16]]
                t2 = [r[tc*16:(tc+1)*16] for r in q_a_all[1][tr*16:(tr+1)*16]]
                t3 = [r[tc*16:(tc+1)*16] for r in q_a_all[2][tr*16:(tr+1)*16]]
                
                B11_1, B12_1 = [r[0:8] for r in t1[0:8]], [r[8:16] for r in t1[0:8]]
                B21_1, B22_1 = [r[0:8] for r in t1[8:16]], [r[8:16] for r in t1[8:16]]
                B11_2, B12_2 = [r[0:8] for r in t2[0:8]], [r[8:16] for r in t2[0:8]]
                B21_2, B22_2 = [r[0:8] for r in t2[8:16]], [r[8:16] for r in t2[8:16]]
                B11_3, B12_3 = [r[0:8] for r in t3[0:8]], [r[8:16] for r in t3[0:8]]
                B21_3, B22_3 = [r[0:8] for r in t3[8:16]], [r[8:16] for r in t3[8:16]]
                
                for q_idx in range(4):
                    q1 = [B11_1, B12_1, B21_1, B22_1][q_idx]
                    q2 = [B11_2, B12_2, B21_2, B22_2][q_idx]
                    q3 = [B11_3, B12_3, B21_3, B22_3][q_idx]
                    for r in range(8):
                        f.write(pack_hex_row_8b(q1[r], q2[r], q3[r]) + "\n")

    with open("input_b.txt", "w") as f:
        for tr in range(4):
            for tc in range(4):
                t1 = [r[tc*16:(tc+1)*16] for r in q_b_all[0][tr*16:(tr+1)*16]]
                t2 = [r[tc*16:(tc+1)*16] for r in q_b_all[1][tr*16:(tr+1)*16]]
                t3 = [r[tc*16:(tc+1)*16] for r in q_b_all[2][tr*16:(tr+1)*16]]
                
                B11_1, B12_1 = [r[0:8] for r in t1[0:8]], [r[8:16] for r in t1[0:8]]
                B21_1, B22_1 = [r[0:8] for r in t1[8:16]], [r[8:16] for r in t1[8:16]]
                B11_2, B12_2 = [r[0:8] for r in t2[0:8]], [r[8:16] for r in t2[0:8]]
                B21_2, B22_2 = [r[0:8] for r in t2[8:16]], [r[8:16] for r in t2[8:16]]
                B11_3, B12_3 = [r[0:8] for r in t3[0:8]], [r[8:16] for r in t3[0:8]]
                B21_3, B22_3 = [r[0:8] for r in t3[8:16]], [r[8:16] for r in t3[8:16]]
                
                for q_idx in range(4):
                    q1 = [B11_1, B12_1, B21_1, B22_1][q_idx]
                    q2 = [B11_2, B12_2, B21_2, B22_2][q_idx]
                    q3 = [B11_3, B12_3, B21_3, B22_3][q_idx]
                    for r in range(8):
                        f.write(pack_hex_row_8b(q1[r], q2[r], q3[r]) + "\n")

    compiler = DLACompiler()
    _, prog_hex = compiler.compile_conv_layer(h=H, w=W, c=C, kh=1, kw=1, stride=1, padding=0, out_channels=out_channels, use_relu=True, simd_mode=False)
    with open("dla_program.hex", "w") as f:
        f.write(prog_hex)

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
        "posit_dsp_packing.v", "dsp48e2_sim_model.v", "posit_dsp_test_part2.v",
        "posit_mult_part1.v", "posit_mult_part3.v", "posit_to_fixed_conv_8b_wide.v"
    ]
    subprocess.run(["iverilog", "-g2012", "-DSIMULATION", "-DNUM_WORDS=512", "-I", ".", "-o", "dla_sim.vvp"] + src_files, check=True)
    subprocess.run(["vvp", "dla_sim.vvp"], check=True)

    with open("dla_output_c.txt", "r") as f:
        out_lines = [line.strip() for line in f.readlines() if line.strip()]

    dla_matrix_c = [[[0.0 for _ in range(64)] for _ in range(64)] for _ in range(3)]
    for tr in range(4):
        for tc in range(4):
            tile_idx = tr * 4 + tc
            tile_lines = out_lines[tile_idx * 32 : (tile_idx + 1) * 32]
            
            C11_t = [parse_hex_row_8b(line) for line in tile_lines[0:8]]
            C12_t = [parse_hex_row_8b(line) for line in tile_lines[8:16]]
            C21_t = [parse_hex_row_8b(line) for line in tile_lines[16:24]]
            C22_t = [parse_hex_row_8b(line) for line in tile_lines[24:32]]
            
            for ch in range(3):
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

    for job in range(3):
        w_scale = weight_scales[job]
        ref_flat = [ref_outputs[job][m][y][x] for m in range(out_channels) for y in range(H) for x in range(W)]
        
        # De-scale hardware output by dividing by weight scale factor
        hw_flat = [(dla_matrix_c[job][idx][m] / w_scale) for m in range(out_channels) for idx in range(64)]
        
        mse = sum((h - r)**2 for h, r in zip(hw_flat, ref_flat)) / len(ref_flat)
        rmse = math.sqrt(mse)
        rms_ref = math.sqrt(sum(r**2 for r in ref_flat) / len(ref_flat))
        rel_rmse = (rmse / rms_ref) * 100.0 if rms_ref > 0 else 0.0
        sqnr_db = 20.0 * math.log10(rms_ref / rmse) if rmse > 0 else 99.0

        print(f"\n--- CALIBRATED JOB {job+1} (End-to-End Layer Hardware Output) ---")
        print(f"  Reference RMS      : {rms_ref:.5f}")
        print(f"  Calibrated RMSE    : {rmse:.5f}")
        print(f"  Relative RMSE      : {rel_rmse:.2f}%  (Math check: 10^(-SQNR/20) = {10**(-sqnr_db/20)*100:.2f}%)")
        print(f"  SQNR (dB)          : {sqnr_db:.2f} dB")

    print("\n" + "=" * 80 + "\n")

if __name__ == "__main__":
    main()
