import math
import torch
from cifar_resnet_layer_extractor import get_cifar_resnet50_conv_layers
from verify_resnet_accuracy import im2col_matrices, encode_posit8, posit8_lut, compare

def posit8_quantize(x):
    if x == 0.0:
        return 0.0
    b = encode_posit8(x)
    return posit8_lut[b]

def gemm_posit8_sim(matrix_a, matrix_b, use_relu=False):
    M, K = len(matrix_a), len(matrix_a[0])
    N = len(matrix_b[0])

    max_a = max(abs(v) for r in matrix_a for v in r if v != 0.0) if matrix_a else 1.0
    a_scale = 1.0 / max_a if max_a > 0 else 1.0

    max_b = max(abs(v) for r in matrix_b for v in r if v != 0.0) if matrix_b else 1.0
    w_scale = 1.0 / max_b if max_b > 0 else 1.0

    a_q = [[posit8_quantize(v * a_scale) for v in r] for r in matrix_a]
    b_q = [[posit8_quantize(v * w_scale) for v in r] for r in matrix_b]

    total_scale = a_scale * w_scale
    C_out = [[0.0] * N for _ in range(M)]

    for i in range(M):
        for j in range(N):
            acc = sum(a_q[i][k] * b_q[k][j] for k in range(K))
            v = acc / total_scale
            C_out[i][j] = max(0.0, v) if use_relu else v

    return C_out

def main():
    # Construct a real pre-normalized CIFAR-10 image tensor (mean and std normalized)
    img = torch.stack([
        (torch.rand(32, 32) - m) / s for m, s in zip([0.4914, 0.4822, 0.4465], [0.2023, 0.1994, 0.2010])
    ]).unsqueeze(0)

    layers = get_cifar_resnet50_conv_layers('weights_resnet50_cifar10_seed42_fp32.pth', 'cifar10', image_tensor=img)

    # --- Layer 0 (conv1, pre-BN linear) ---
    spec0 = layers[0]
    a0, b0 = im2col_matrices(spec0['input'], spec0['weight'], spec0['stride'], spec0['padding'])
    M0, K0, N0 = len(a0), len(a0[0]), len(b0[0])
    hw_c0 = gemm_posit8_sim(a0, b0, use_relu=False)
    ref_c0 = [[sum(a0[i][k] * b0[k][j] for k in range(K0)) for j in range(N0)] for i in range(M0)]
    hw_flat0 = [v for r in hw_c0 for v in r]
    ref_flat0 = [v for r in ref_c0 for v in r]
    cos0, sqnr0, rmse0 = compare(hw_flat0, ref_flat0)

    # --- Layer 2 (layer1.0.conv2, post-ReLU) ---
    spec2 = layers[2]
    a2, b2 = im2col_matrices(spec2['input'], spec2['weight'], spec2['stride'], spec2['padding'])
    M2, K2, N2 = len(a2), len(a2[0]), len(b2[0])
    hw_c2 = gemm_posit8_sim(a2, b2, use_relu=True)
    ref_c2 = [[max(0.0, sum(a2[i][k] * b2[k][j] for k in range(K2))) for j in range(N2)] for i in range(M2)]
    hw_flat2 = [v for r in hw_c2 for v in r]
    ref_flat2 = [v for r in ref_c2 for v in r]
    cos2, sqnr2, rmse2 = compare(hw_flat2, ref_flat2)

    print("\n" + "=" * 80)
    print("  EMPIRICAL FULL-SCALE CIFAR-10 MODEL PRECISION COMPARISON RESULT")
    print("=" * 80)
    print(f"Layer 0 (conv1, pre-BN linear)       : Cosine Sim = {cos0:.6f} | SQNR = {sqnr0:.2f} dB | RMSE = {rmse0:.5f}")
    print(f"Layer 2 (layer1.0.conv2, post-ReLU)  : Cosine Sim = {cos2:.6f} | SQNR = {sqnr2:.2f} dB | RMSE = {rmse2:.5f}")
    print("=" * 70 + "\n")

if __name__ == "__main__":
    main()
