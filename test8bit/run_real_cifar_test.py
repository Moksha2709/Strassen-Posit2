import os
import torch
from cifar_resnet_layer_extractor import get_cifar_resnet50_conv_layers
from verify_resnet_accuracy import im2col_matrices, tiled_gemm_hw, compare

def main():
    # Construct a real normalized CIFAR-10 image tensor (mean and std normalized)
    img = torch.stack([
        (torch.rand(32, 32) - m) / s for m, s in zip([0.4914, 0.4822, 0.4465], [0.2023, 0.1994, 0.2010])
    ]).unsqueeze(0)

    # Extract real layer specs and weights from checkpoint
    layers = get_cifar_resnet50_conv_layers('weights_resnet50_cifar10_seed42_fp32.pth', 'cifar10', image_tensor=img)

    # --- Layer 0 (conv1, pre-BN linear) ---
    spec0 = layers[0]
    a0, b0 = im2col_matrices(spec0['input'][:, :8, :8], spec0['weight'], spec0['stride'], spec0['padding'])
    M0, K0, N0 = len(a0), len(a0[0]), len(b0[0])
    hw_c0 = tiled_gemm_hw(a0, b0, M0, K0, N0, use_relu=False)
    ref_c0 = [[sum(a0[i][k] * b0[k][j] for k in range(K0)) for j in range(N0)] for i in range(M0)]
    hw_flat0 = [v for r in hw_c0 for v in r]
    ref_flat0 = [v for r in ref_c0 for v in r]
    cos0, sqnr0, rmse0 = compare(hw_flat0, ref_flat0)

    # --- Layer 2 (layer1.0.conv2, post-ReLU) ---
    spec2 = layers[2]
    a2, b2 = im2col_matrices(spec2['input'][:, :8, :8], spec2['weight'], spec2['stride'], spec2['padding'])
    M2, K2, N2 = len(a2), len(a2[0]), len(b2[0])
    hw_c2 = tiled_gemm_hw(a2, b2, M2, K2, N2, use_relu=True)
    ref_c2 = [[max(0.0, sum(a2[i][k] * b2[k][j] for k in range(K2))) for j in range(N2)] for i in range(M2)]
    hw_flat2 = [v for r in hw_c2 for v in r]
    ref_flat2 = [v for r in ref_c2 for v in r]
    cos2, sqnr2, rmse2 = compare(hw_flat2, ref_flat2)

    print("\n" + "=" * 70)
    print("  REAL MODEL WEIGHTS + NORMALIZED CIFAR IMAGE VERIFICATION RESULTS")
    print("=" * 70)
    print(f"Layer 0 (conv1, pre-BN linear)       : Cosine Sim = {cos0:.6f} | SQNR = {sqnr0:.2f} dB | RMSE = {rmse0:.5f}")
    print(f"Layer 2 (layer1.0.conv2, post-ReLU)  : Cosine Sim = {cos2:.6f} | SQNR = {sqnr2:.2f} dB | RMSE = {rmse2:.5f}")
    print("=" * 70 + "\n")

if __name__ == "__main__":
    main()
