# =============================================================================
# verify_16bit_unit_accuracy.py — Fast Standalone 16-Bit Q8.8 Unit Benchmark
# =============================================================================
# Evaluates 100% TRUE RTL Verilog Hardware Accuracy for the 16-Bit Q8.8 Strassen DLA Unit.
# Runs a single 16x16 tile in < 1 second and reports:
# - Cosine Similarity, SQNR (dB), and RMSE vs FP32 ground truth
# =============================================================================
import os
import sys
import math
import random
import numpy as np

from verify_16bit_resnet_hardware import (
    compile_verilog_netlist, write_quadrant_file, read_output_quadrants, run_one_16x16_tile
)

def generate_random_matrix(rows, cols, min_val=-1.0, max_val=1.0, seed=42):
    random.seed(seed)
    return [[random.uniform(min_val, max_val) for _ in range(cols)] for _ in range(rows)]

def matmul_fp32(A, B):
    M = len(A)
    K = len(A[0])
    N = len(B[0])
    C = [[0.0] * N for _ in range(M)]
    for i in range(M):
        for k in range(K):
            a_val = A[i][k]
            for j in range(N):
                C[i][j] += a_val * B[k][j]
    return C

def compute_accuracy_metrics(pred_matrix, ref_matrix):
    pred = np.array(pred_matrix, dtype=np.float32).flatten()
    ref = np.array(ref_matrix, dtype=np.float32).flatten()

    dot_product = np.dot(pred, ref)
    norm_pred = np.linalg.norm(pred)
    norm_ref = np.linalg.norm(ref)

    if norm_pred == 0 or norm_ref == 0:
        cosine_sim = 0.0
    else:
        cosine_sim = float(dot_product / (norm_pred * norm_ref))

    mse = np.mean((pred - ref) ** 2)
    rmse = float(np.sqrt(mse))

    signal_power = np.mean(ref ** 2)
    noise_power = mse

    if noise_power == 0:
        sqnr_db = 100.0
    elif signal_power == 0:
        sqnr_db = -100.0
    else:
        sqnr_db = float(10 * np.log10(signal_power / noise_power))

    return cosine_sim, sqnr_db, rmse

def main():
    print("=" * 80)
    print("      16-BIT Q8.8 STRASSEN DLA: SINGLE-UNIT ACCURACY AUDIT")
    print("=" * 80)

    TILE_SIZE = 16

    print(f"\n[1/3] Generating random FP32 matrix pair (Tile Size: {TILE_SIZE}x{TILE_SIZE})...")
    a = generate_random_matrix(TILE_SIZE, TILE_SIZE, min_val=-1.0, max_val=1.0, seed=123)
    b = generate_random_matrix(TILE_SIZE, TILE_SIZE, min_val=-1.0, max_val=1.0, seed=456)

    print("[2/3] Computing FP32 Ground Truth...")
    c_ref = matmul_fp32(a, b)

    print("[3/3] Compiling Verilog RTL source files (.v) on the fly & executing tile simulation...")
    sim_bin = compile_verilog_netlist("temp_16bit_unit_sim.vvp")
    try:
        c_hw = run_one_16x16_tile(a, b, sim_bin=sim_bin)
    finally:
        if os.path.exists(sim_bin):
            os.remove(sim_bin)

    cosine_sim, sqnr_db, rmse = compute_accuracy_metrics(c_hw, c_ref)

    print("\n" + "=" * 80)
    print("                 16-BIT Q8.8 UNIT ACCURACY RESULTS")
    print("=" * 80)
    print(f"  Single 16x16 Tile -> Cosine Sim: {cosine_sim:.6f} | SQNR: {sqnr_db:6.2f} dB | RMSE: {rmse:.5f}")
    print("=" * 80 + "\n")

if __name__ == "__main__":
    main()
