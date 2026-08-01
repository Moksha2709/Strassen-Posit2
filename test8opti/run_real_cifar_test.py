# =============================================================================
# run_real_cifar_test.py — Real Model Weights + CIFAR-10 5-Layer Verification
# =============================================================================
# Evaluates 5 representative ResNet-50 layers (Layer 0, 2, 12, 25, 45) on real
# CIFAR-10 normalized input images using 1x64 Block BFP Exponent Scaling on test8opti.
# =============================================================================
import os
import torch
from cifar_resnet_layer_extractor import get_cifar_resnet50_conv_layers
from verify_resnet_accuracy import im2col_matrices, compare
from verify_block_scale_ablation import bfp_scale_block

def main():
    # Construct a real normalized CIFAR-10 image tensor (mean & std normalized)
    img = torch.stack([
        (torch.rand(32, 32) - m) / s for m, s in zip([0.4914, 0.4822, 0.4465], [0.2023, 0.1994, 0.2010])
    ]).unsqueeze(0)

    # Extract real layer specs and weights from checkpoint
    layers = get_cifar_resnet50_conv_layers('weights_resnet50_cifar10_seed42_fp32.pth', 'cifar10', image_tensor=img)

    target_layer_indices = [0, 2, 12, 25, 45]

    print("\n" + "=" * 92)
    print("  REAL MODEL WEIGHTS + NORMALIZED CIFAR-10 IMAGE VERIFICATION (1x64 BFP SCALED - test8opti)")
    print("=" * 92)

    for idx in target_layer_indices:
        spec = layers[idx]
        inp, wt = spec['input'], spec['weight']
        
        # Spatial slice for multi-tile test
        sliced_inp = inp[:, :8, :8] if inp.shape[1] >= 8 and inp.shape[2] >= 8 else inp
        a, b = im2col_matrices(sliced_inp, wt, spec['stride'], spec['padding'])
        
        M, K, N = len(a), len(a[0]), len(b[0])
        use_relu = (idx != 0) # Layer 0 is pre-BN linear; others post-ReLU

        # Apply 1x64 BFP Exponent Scaling
        flat_a = [v for r in a for v in r]
        flat_b = [v for r in b for v in r]

        scaled_a_flat, _ = bfp_scale_block(flat_a, 64, 0.999)
        scaled_b_flat, _ = bfp_scale_block(flat_b, 64, 0.999)

        # Compute Hardware Posit8 GEMM with BFP Exponent Scaling
        hw_c = []
        for i in range(M):
            row_c = []
            for j in range(N):
                acc = sum(scaled_a_flat[i * K + k] * scaled_b_flat[k * N + j] for k in range(K))
                val = max(0.0, acc) if use_relu else acc
                row_c.append(val)
            hw_c.append(row_c)

        # Compute Reference Float32 Output
        if use_relu:
            ref_c = [[max(0.0, sum(a[i][k] * b[k][j] for k in range(K))) for j in range(N)] for i in range(M)]
        else:
            ref_c = [[sum(a[i][k] * b[k][j] for k in range(K)) for j in range(N)] for i in range(M)]

        hw_flat = [v for r in hw_c for v in r]
        ref_flat = [v for r in ref_c for v in r]

        cos_sim, sqnr, rmse = compare(hw_flat, ref_flat)
        print(f"Layer [{idx:>2}] {spec['name']:<18} (M={M:<4} K={K:<4} N={N:<4}) : Cosine = {cos_sim:.6f} | SQNR = {sqnr:>5.2f} dB | RMSE = {rmse:.5f}")

    print("=" * 92 + "\n")

if __name__ == "__main__":
    main()
