# =============================================================================
# eval_accuracy.py — Accuracy evaluation script for 16x16 fixed-point matmul
# =============================================================================
import os
import math
import random
import subprocess

def decode_fixed16(b):
    # interpret as signed 16-bit integer
    if b >= 32768:
        val = b - 65536
    else:
        val = b
    return val / 16.0

def encode_fixed16(x):
    if x is None or math.isnan(x):
        return 0
    val = round(x * 16.0)
    val = max(-32768, min(32767, val))
    return val & 0xffff

def float_to_hex_row(row_vals):
    fixed_words = [encode_fixed16(x) for x in row_vals]
    hex_str = "".join(f"{val:04x}" for val in reversed(fixed_words))
    return hex_str

def parse_hex_row(hex_str):
    hex_str = hex_str.zfill(32)
    row_vals = []
    for i in range(8):
        word_str = hex_str[32 - 4*(i+1) : 32 - 4*i]
        val_word = int(word_str, 16)
        row_vals.append(decode_fixed16(val_word))
    return row_vals

def run_sim():
    print("[INFO] Compiling Verilog files with iverilog...")
    files = [
        "eval_tb.v",
        "fixed_pe.v",
        "fixed_mac_array.v",
        "fixed_mxu.v",
        "strassen_controller.v",
        "strassen_preprocess.v",
        "strassen_scratchpad.v",
        "strassen_top.v"
    ]
    cmd_compile = ["iverilog", "-g2012", "-I", ".", "-o", "eval_sim.vvp"] + files
    subprocess.run(cmd_compile, check=True)
    
    print("[INFO] Running simulation with vvp...")
    subprocess.run(["vvp", "eval_sim.vvp"], check=True)

def matmul_ref_int8(A, B):
    max_a = max(max(abs(x) for x in row) for row in A)
    max_b = max(max(abs(x) for x in row) for row in B)
    scale_a = max_a / 127.0 if max_a > 0 else 1.0
    scale_b = max_b / 127.0 if max_b > 0 else 1.0
    
    qA = [[clip_int8(round(x / scale_a)) for x in row] for row in A]
    qB = [[clip_int8(round(x / scale_b)) for x in row] for row in B]
    
    qC = [[0]*16 for _ in range(16)]
    for i in range(16):
        for j in range(16):
            acc = 0
            for k in range(16):
                acc += qA[i][k] * qB[k][j]
            qC[i][j] = acc
            
    C_int8 = [[x * scale_a * scale_b for x in row] for row in qC]
    return C_int8

def clip_int8(val):
    return max(-128, min(127, val))

def main():
    print("[INFO] Generating random 16x16 test matrices...")
    random.seed(42)
    A = [[random.normalvariate(0, 0.5) for _ in range(16)] for _ in range(16)]
    B = [[random.normalvariate(0, 0.5) for _ in range(16)] for _ in range(16)]
    
    A11 = [row[0:8] for row in A[0:8]]
    A12 = [row[8:16] for row in A[0:8]]
    A21 = [row[0:8] for row in A[8:16]]
    A22 = [row[8:16] for row in A[8:16]]
    
    B11 = [row[0:8] for row in B[0:8]]
    B12 = [row[8:16] for row in B[0:8]]
    B21 = [row[0:8] for row in B[8:16]]
    B22 = [row[8:16] for row in B[8:16]]
    
    with open("input_a.txt", "w") as f:
        for tile in [A11, A12, A21, A22]:
            for row in tile:
                f.write(float_to_hex_row(row) + "\n")
                
    with open("input_b.txt", "w") as f:
        for tile in [B11, B12, B21, B22]:
            for row in tile:
                f.write(float_to_hex_row(row) + "\n")
                
    run_sim()
    
    print("[INFO] Parsing hardware outputs...")
    with open("output_c.txt", "r") as f:
        lines = [line.strip() for line in f.readlines() if line.strip()]
        
    C11 = [parse_hex_row(line) for line in lines[0:8]]
    C12 = [parse_hex_row(line) for line in lines[8:16]]
    C21 = [parse_hex_row(line) for line in lines[16:24]]
    C22 = [parse_hex_row(line) for line in lines[24:32]]
    
    C_hw = []
    for i in range(8):
        C_hw.append(C11[i] + C12[i])
    for i in range(8):
        C_hw.append(C21[i] + C22[i])
        
    print("[INFO] Calculating comparison models...")
    C_gt = [[0.0]*16 for _ in range(16)]
    for i in range(16):
        for j in range(16):
            val = 0.0
            for k in range(16):
                val += A[i][k] * B[k][j]
            C_gt[i][j] = val
            
    C_ref = matmul_ref_int8(A, B)
    
    signal_power = sum(sum(x**2 for x in row) for row in C_gt) / 256.0
    
    def transpose(M):
        return [list(x) for x in zip(*M)]
    def matmul(X, Y):
        res = [[0.0]*len(Y[0]) for _ in range(len(X))]
        for i in range(len(X)):
            for j in range(len(Y[0])):
                for k in range(len(Y)):
                    res[i][j] += X[i][k] * Y[k][j]
        return res

    AT = transpose(A)
    BT = transpose(B)
    options = {
        "A * B (standard)": matmul(A, B),
        "(A * B)^T": transpose(matmul(A, B)),
        "B * A": matmul(B, A),
        "(B * A)^T": transpose(matmul(B, A)),
        "A^T * B": matmul(AT, B),
        "A * B^T": matmul(A, BT),
        "A^T * B^T": matmul(AT, BT),
        "B^T * A^T": matmul(BT, AT),
    }
    
    print("\n--- TRANPOSITION DIAGNOSTICS ---")
    for name, C_test in options.items():
        mse_test = sum(sum((C_hw[i][j] - C_test[i][j])**2 for j in range(16)) for i in range(16)) / 256.0
        print(f"Config: {name:<20} | MSE: {mse_test:<10.3e}")
    print("--------------------------------\n")

    fixed_mse = sum(sum((C_hw[i][j] - C_gt[i][j])**2 for j in range(16)) for i in range(16)) / 256.0
    fixed_rmse = math.sqrt(fixed_mse)
    fixed_rrmse = fixed_rmse / math.sqrt(signal_power)
    fixed_sqnr = 10 * math.log10(signal_power / fixed_mse) if fixed_mse > 0 else float('inf')
    
    ref_mse = sum(sum((C_ref[i][j] - C_gt[i][j])**2 for j in range(16)) for i in range(16)) / 256.0
    ref_rmse = math.sqrt(ref_mse)
    ref_rrmse = ref_rmse / math.sqrt(signal_power)
    ref_sqnr = 10 * math.log10(signal_power / ref_mse) if ref_mse > 0 else float('inf')
    
    print("\nSample values of C_gt[0][:5] (Ground Truth):")
    print([f"{x:.4f}" for x in C_gt[0][:5]])
    print("Sample values of C_hw[0][:5] (Hardware output):")
    print([f"{x:.4f}" for x in C_hw[0][:5]])
    print("Sample values of C_ref[0][:5] (INT8 reference):")
    print([f"{x:.4f}" for x in C_ref[0][:5]])

    print("\n" + "="*65)
    print("      ACCURACY EVALUATION RESULTS (16x16 Matrix Multiply)")
    print("="*65)
    print(f"{'Metric':<25} | {'Reference GEMM (INT8)':<20} | {'Our 16-bit Fixed Q8.8':<20}")
    print("-"*65)
    print(f"{'Mean Squared Error':<25} | {ref_mse:<20.3e} | {fixed_mse:<20.3e}")
    print(f"{'Root Mean Squared Error':<25} | {ref_rmse:<20.5f} | {fixed_rmse:<20.5f}")
    print(f"{'Relative RMSE (RRMSE)':<25} | {ref_rrmse*100:<19.2f}% | {fixed_rrmse*100:<19.2f}%")
    print(f"{'SQNR (dB)':<25} | {ref_sqnr:<20.2f} | {fixed_sqnr:<20.2f}")
    print("="*65)
    print("[SUCCESS] Accuracy check completed!\n")

if __name__ == "__main__":
    main()
