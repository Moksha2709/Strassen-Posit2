# =============================================================================
# verify_triple_packed_unit_accuracy_pth.py — Single 8-Bit Unit Benchmark with .pth Model Weights
# =============================================================================
# Evaluates 100% TRUE Verilog RTL Hardware Tile Accuracy for the 3-Way Triple-Packed
# Posit Unit using real trained weights & activations from a PyTorch (.pth) model checkpoint.
# =============================================================================
import os
import sys
import math
import argparse
import torch
import numpy as np

from cifar_resnet_layer_extractor import get_cifar_resnet50_conv_layers
from verify_resnet_accuracy import compile_verilog, run_hw_tile, compare
from verify_triple_packed_unit_accuracy import matmul_fp32

def im2col_matrices(inp_chw, weight_oihw, stride, padding):
    C, H, W = inp_chw.shape
    O, _, kh, kw = weight_oihw.shape
    unfold = torch.nn.Unfold(kernel_size=(kh, kw), stride=stride, padding=padding)
    inp_unfolded = unfold(inp_chw.unsqueeze(0)).squeeze(0).transpose(0, 1)
    wt_flattened = weight_oihw.reshape(O, -1).transpose(0, 1)
    return inp_unfolded.tolist(), wt_flattened.tolist()

def pad_to_64x64(mat):
    padded = [[0.0] * 64 for _ in range(64)]
    for r in range(min(64, len(mat))):
        for c in range(min(64, len(mat[0]))):
            padded[r][c] = mat[r][c]
    return padded

def find_weights_file(custom_path=None):
    candidates = []
    if custom_path:
        candidates.append(custom_path)
    
    candidates.extend([
        "weights_resnet50_cifar10_seed42_fp32.pth",
        "../weights_resnet50_cifar10_seed42_fp32.pth",
        "../test8bit/weights_resnet50_cifar10_seed42_fp32.pth",
        "../../test8bit/weights_resnet50_cifar10_seed42_fp32.pth",
        "test8bit/weights_resnet50_cifar10_seed42_fp32.pth",
        os.path.expanduser("~/test8bit/weights_resnet50_cifar10_seed42_fp32.pth"),
        os.path.expanduser("~/8bitnew/test8bit/weights_resnet50_cifar10_seed42_fp32.pth"),
        os.path.expanduser("~/test8opti/weights_resnet50_cifar10_seed42_fp32.pth"),
        "ckpt_resnet50_cifar10_seed42_epoch125.pth",
        "../ckpt_resnet50_cifar10_seed42_epoch125.pth",
    ])
    for path in candidates:
        if os.path.exists(path):
            return path, candidates
    return None, candidates

def main():
    parser = argparse.ArgumentParser(description="Single 8-Bit Posit Unit Accuracy (.pth weights)")
    parser.add_argument("--weights", default=None, help="Path to PyTorch model weights checkpoint (.pth)")
    args = parser.parse_args()

    print("=" * 80)
    print("  8-BIT TRIPLE-PACKED POSIT DLA: SINGLE-UNIT ACCURACY AUDIT (.PTH MODEL WEIGHTS)")
    print("=" * 80)

    weights_path, checked_paths = find_weights_file(args.weights)
    if not weights_path:
        print("[ERR] Could not find PyTorch model checkpoint (.pth) file!")
        print("Checked paths:")
        for p in checked_paths:
            print(f"  - {p}")
        print("\nPlease specify your weights file via --weights argument:")
        print("  python3 verify_triple_packed_unit_accuracy_pth.py --weights /path/to/weights.pth\n")
        sys.exit(1)

    print(f"\n[1/3] Loading PyTorch model checkpoint: {weights_path}...")
    layers = get_cifar_resnet50_conv_layers(weights_path=weights_path, dataset_name="cifar10")

    # Select 3 distinct layers for the 3 triple-packed lanes
    l1_spec = layers[0]  # conv1
    l2_spec = layers[2]  # layer1.0.conv2
    l3_spec = layers[3]  # layer1.0.conv3

    print(f"      Lane 1 Layer: {l1_spec['name']}")
    print(f"      Lane 2 Layer: {l2_spec['name']}")
    print(f"      Lane 3 Layer: {l3_spec['name']}")

    print("\n[2/3] Performing im2col extraction and slicing 64x64 GEMM tiles for each lane...")
    m1_a, m1_b = im2col_matrices(l1_spec["input"], l1_spec["weight"], l1_spec["stride"], l1_spec["padding"])
    m2_a, m2_b = im2col_matrices(l2_spec["input"], l2_spec["weight"], l2_spec["stride"], l2_spec["padding"])
    m3_a, m3_b = im2col_matrices(l3_spec["input"], l3_spec["weight"], l3_spec["stride"], l3_spec["padding"])

    # Slice and pad 64x64 tiles
    a1, b1 = pad_to_64x64(m1_a), pad_to_64x64(m1_b)
    a2, b2 = pad_to_64x64(m2_a), pad_to_64x64(m2_b)
    a3, b3 = pad_to_64x64(m3_a), pad_to_64x64(m3_b)

    print("\n[3/3] Computing FP32 Ground Truth & Executing Verilog RTL Hardware Tile (`vvp dla_sim.vvp`)...")
    c1_ref = matmul_fp32(a1, b1)
    c2_ref = matmul_fp32(a2, b2)
    c3_ref = matmul_fp32(a3, b3)

    compile_verilog()
    hw_outputs = run_hw_tile([a1, a2, a3], [b1, b2, b3])

    c1_hw, c2_hw, c3_hw = hw_outputs[0], hw_outputs[1], hw_outputs[2]

    # Evaluate accuracy metrics
    cos1, sqnr1, rmse1 = compare([val for row in c1_hw for val in row], [val for row in c1_ref for val in row])
    cos2, sqnr2, rmse2 = compare([val for row in c2_hw for val in row], [val for row in c2_ref for val in row])
    cos3, sqnr3, rmse3 = compare([val for row in c3_hw for val in row], [val for row in c3_ref for val in row])

    avg_cos = (cos1 + cos2 + cos3) / 3.0
    avg_sqnr = (sqnr1 + sqnr2 + sqnr3) / 3.0
    avg_rmse = (rmse1 + rmse2 + rmse3) / 3.0

    print("\n" + "=" * 80)
    print("         TRIPLE-PACKED UNIT ACCURACY RESULTS (.PTH MODEL DATA)")
    print("=" * 80)
    print(f"  Lane 1 ({l1_spec['name']}) -> Cosine Sim: {cos1:.6f} | SQNR: {sqnr1:6.2f} dB | RMSE: {rmse1:.5f}")
    print(f"  Lane 2 ({l2_spec['name']}) -> Cosine Sim: {cos2:.6f} | SQNR: {sqnr2:6.2f} dB | RMSE: {rmse2:.5f}")
    print(f"  Lane 3 ({l3_spec['name']}) -> Cosine Sim: {cos3:.6f} | SQNR: {sqnr3:6.2f} dB | RMSE: {rmse3:.5f}")
    print("-" * 80)
    print(f"  TRIPLE-UNIT AVERAGE        -> Cosine Sim: {avg_cos:.6f} | SQNR: {avg_sqnr:6.2f} dB | RMSE: {avg_rmse:.5f}")
    print("=" * 80 + "\n")

if __name__ == "__main__":
    main()
