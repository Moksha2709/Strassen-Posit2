# =============================================================================
# verify_triple_packed_unit_accuracy.py — Fast Standalone Posit Unit Benchmark
# =============================================================================
# Evaluates 100% TRUE RTL Verilog Hardware Accuracy for the 3-Way Triple-Packed
# Posit Processing Element / DLA Unit across 3 independent matrix multiplication jobs.
#
# Runs a single 64x64 GEMM tile in < 1 second and reports:
# - Lane 1 (Channel 1) Cosine Sim, SQNR, RMSE
# - Lane 2 (Channel 2) Cosine Sim, SQNR, RMSE
# - Lane 3 (Channel 3) Cosine Sim, SQNR, RMSE
# =============================================================================
import os
import sys
import math
import random
import numpy as np

from verify_resnet_accuracy import (
    compile_verilog, run_hw_tile, compare
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

def main():
    print("=" * 80)
    print("      8-BIT TRIPLE-PACKED POSIT DLA: SINGLE-UNIT ACCURACY AUDIT")
    print("=" * 80)

    # Size of 1 single hardware GEMM tile
    TILE_SIZE = 64

    print(f"\n[1/3] Generating 3 independent random FP32 matrix pairs (Tile Size: {TILE_SIZE}x{TILE_SIZE})...")
    
    # 3 distinct input job pairs for the 3 packed lanes
    a1 = generate_random_matrix(TILE_SIZE, TILE_SIZE, min_val=-0.8, max_val=0.8, seed=101)
    b1 = generate_random_matrix(TILE_SIZE, TILE_SIZE, min_val=-0.8, max_val=0.8, seed=102)

    a2 = generate_random_matrix(TILE_SIZE, TILE_SIZE, min_val=-1.2, max_val=1.2, seed=201)
    b2 = generate_random_matrix(TILE_SIZE, TILE_SIZE, min_val=-1.2, max_val=1.2, seed=202)

    a3 = generate_random_matrix(TILE_SIZE, TILE_SIZE, min_val=-0.5, max_val=0.5, seed=301)
    b3 = generate_random_matrix(TILE_SIZE, TILE_SIZE, min_val=-0.5, max_val=0.5, seed=302)

    print("[2/3] Computing FP32 Ground Truth for Lane 1, Lane 2, and Lane 3...")
    c1_ref = matmul_fp32(a1, b1)
    c2_ref = matmul_fp32(a2, b2)
    c3_ref = matmul_fp32(a3, b3)

    print("[3/3] Executing 100% True Verilog RTL Hardware Tile (`vvp dla_sim.vvp`)...")
    compile_verilog()
    hw_outputs = run_hw_tile([a1, a2, a3], [b1, b2, b3])

    c1_hw, c2_hw, c3_hw = hw_outputs[0], hw_outputs[1], hw_outputs[2]

    # Evaluate accuracy metrics for each lane
    cos1, sqnr1, rmse1 = compare(c1_hw, c1_ref)
    cos2, sqnr2, rmse2 = compare(c2_hw, c2_ref)
    cos3, sqnr3, rmse3 = compare(c3_hw, c3_ref)

    avg_cos = (cos1 + cos2 + cos3) / 3.0
    avg_sqnr = (sqnr1 + sqnr2 + sqnr3) / 3.0
    avg_rmse = (rmse1 + rmse2 + rmse3) / 3.0

    print("\n" + "=" * 80)
    print("                    TRIPLE-PACKED UNIT ACCURACY RESULTS")
    print("=" * 80)
    print(f"  Lane 1 (Channel 1) -> Cosine Sim: {cos1:.6f} | SQNR: {sqnr1:6.2f} dB | RMSE: {rmse1:.5f}")
    print(f"  Lane 2 (Channel 2) -> Cosine Sim: {cos2:.6f} | SQNR: {sqnr2:6.2f} dB | RMSE: {rmse2:.5f}")
    print(f"  Lane 3 (Channel 3) -> Cosine Sim: {cos3:.6f} | SQNR: {sqnr3:6.2f} dB | RMSE: {rmse3:.5f}")
    print("-" * 80)
    print(f"  TRIPLE-UNIT AVERAGE -> Cosine Sim: {avg_cos:.6f} | SQNR: {avg_sqnr:6.2f} dB | RMSE: {avg_rmse:.5f}")
    print("=" * 80 + "\n")

if __name__ == "__main__":
    main()
