# =============================================================================
# verify_16bit_unit_accuracy_pth.py — Single 16-Bit Unit Benchmark with .pth Model Weights
# =============================================================================
# Evaluates 100% TRUE Verilog RTL Hardware Tile Accuracy for the 16-Bit Q8.8 Unit
# using real trained weights & activations from a PyTorch (.pth) model checkpoint.
# =============================================================================
import os
import sys
import math
import torch
import numpy as np

sys.path.append(os.path.abspath("../test8bit"))
from cifar_resnet_layer_extractor import get_cifar_resnet50_conv_layers
from verify_16bit_resnet_cifar_accuracy import im2col_matrices
from verify_16bit_unit_accuracy import (
    compile_verilog_netlist, run_one_16x16_tile, compute_accuracy_metrics, matmul_fp32
)

def main():
    print("=" * 80)
    print("  16-BIT Q8.8 STRASSEN DLA: SINGLE-UNIT ACCURACY AUDIT (.PTH MODEL WEIGHTS)")
    print("=" * 80)

    weights_path = "../test8bit/weights_resnet50_cifar10_seed42_fp32.pth"
    if not os.path.exists(weights_path):
        weights_path = "weights_resnet50_cifar10_seed42_fp32.pth"

    print(f"\n[1/3] Loading PyTorch model checkpoint: {weights_path}...")
    layers = get_cifar_resnet50_conv_layers(weights_path=weights_path, dataset_name="cifar10")
    
    spec = layers[0] # conv1
    print(f"      Selected Layer: {spec['name']} | Input Shape: {spec['input'].shape} | Weight Shape: {spec['weight'].shape}")

    print("[2/3] Performing im2col extraction and slicing a single 16x16 GEMM tile...")
    matrix_a, matrix_b = im2col_matrices(spec["input"], spec["weight"], spec["stride"], spec["padding"])
    
    tile_a = [row[:16] for row in matrix_a[:16]]
    tile_b = [row[:16] for row in matrix_b[:16]]

    print("[3/3] Computing FP32 Ground Truth & Executing Verilog RTL Hardware Tile (`vvp eval_sim.vvp`)...")
    c_ref = matmul_fp32(tile_a, tile_b)
    compile_verilog_netlist()
    c_hw = run_one_16x16_tile(tile_a, tile_b)

    cosine_sim, sqnr_db, rmse = compute_accuracy_metrics(c_hw, c_ref)

    print("\n" + "=" * 80)
    print("          16-BIT Q8.8 UNIT ACCURACY RESULTS (.PTH MODEL DATA)")
    print("=" * 80)
    print(f"  Layer: {spec['name']} (16x16 Tile) -> Cosine Sim: {cosine_sim:.6f} | SQNR: {sqnr_db:6.2f} dB | RMSE: {rmse:.5f}")
    print("=" * 80 + "\n")

if __name__ == "__main__":
    main()
