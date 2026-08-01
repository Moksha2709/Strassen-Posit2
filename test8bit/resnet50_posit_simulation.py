#!/usr/bin/env python3
"""
resnet50_posit_simulation.py — Software-Only ResNet-50 Posit Accuracy Simulation

Compares float32 reference vs 12-bit posit (es=1) vs 6-bit posit (es=1)
accuracy across all layers of ResNet-50.

Uses a scaled-down 8x8 input image. Pure Python standard library (no numpy).
"""
import math
import random
import time
import bisect

# ============================================================================
# 1. Posit Quantization Engine
# ============================================================================

def decode_posit(code, n, es):
    """Decode an n-bit posit integer code to its float value."""
    if code == 0:
        return 0.0
    nar = 1 << (n - 1)
    if code == nar:
        return float('nan')
    sign = 0
    if code >= nar:
        sign = 1
        code = ((1 << n) - code) & ((1 << n) - 1)
    bits = format(code, f'0{n}b')
    idx = 1
    if bits[1] == '1':
        run = 0
        while idx < n and bits[idx] == '1':
            run += 1; idx += 1
        if idx < n: idx += 1
        k = run - 1
    else:
        run = 0
        while idx < n and bits[idx] == '0':
            run += 1; idx += 1
        if idx < n: idx += 1
        k = -run
    e = 0
    for _ in range(es):
        e <<= 1
        if idx < n:
            e |= int(bits[idx]); idx += 1
    frac = 1.0; bit_val = 0.5
    while idx < n:
        if bits[idx] == '1': frac += bit_val
        bit_val /= 2; idx += 1
    useed = 2 ** (2 ** es)
    value = (useed ** k) * (2 ** e) * frac
    return -value if sign else value


def build_posit_lut(n, es):
    """Build sorted list of all representable (non-NaR) posit float values."""
    vals = []
    for code in range(1 << n):
        v = decode_posit(code, n, es)
        if not math.isnan(v):
            vals.append(v)
    vals.sort()
    return vals


def quantize_scalar(value, lut):
    """Snap a scalar to the nearest posit value using binary search."""
    idx = bisect.bisect_left(lut, value)
    candidates = []
    if idx > 0: candidates.append(lut[idx - 1])
    if idx < len(lut): candidates.append(lut[idx])
    if not candidates: return 0.0
    return min(candidates, key=lambda v: abs(v - value))


# ============================================================================
# 2. 3D Tensor Operations (H x W x C stored as flat lists)
# ============================================================================
# Tensors are stored as flat Python lists with shape metadata.
# Access: t[h * W * C + w * C + c]

def make_tensor(H, W, C, fill=0.0):
    return [fill] * (H * W * C), (H, W, C)

def tensor_get(data, shape, h, w, c):
    H, W, C = shape
    return data[h * W * C + w * C + c]

def tensor_set(data, shape, h, w, c, val):
    H, W, C = shape
    data[h * W * C + w * C + c] = val

def quantize_tensor(data, lut):
    """Quantize all elements of a flat tensor list to nearest posit."""
    return [quantize_scalar(v, lut) for v in data]


# ============================================================================
# 3. Convolution (im2col conceptual, but direct loops)
# ============================================================================

def conv2d(x_data, x_shape, w_data, w_shape, stride=1, padding=0):
    """
    x: (H, W, Cin) — activation
    w: (Cout, K, K, Cin) — weight stored as flat list
    Returns: (out_data, out_shape) where out_shape = (Ho, Wo, Cout)
    """
    H, W, Cin = x_shape
    Cout = w_shape[0]
    K = w_shape[1]

    Ho = (H + 2 * padding - K) // stride + 1
    Wo = (W + 2 * padding - K) // stride + 1
    out_data = [0.0] * (Ho * Wo * Cout)
    out_shape = (Ho, Wo, Cout)

    for oh in range(Ho):
        for ow in range(Wo):
            for co in range(Cout):
                acc = 0.0
                for kh in range(K):
                    for kw in range(K):
                        ih = oh * stride - padding + kh
                        iw = ow * stride - padding + kw
                        if 0 <= ih < H and 0 <= iw < W:
                            for ci in range(Cin):
                                x_val = x_data[ih * W * Cin + iw * Cin + ci]
                                # w index: [co, kh, kw, ci]
                                w_idx = co * (K * K * Cin) + kh * (K * Cin) + kw * Cin + ci
                                acc += x_val * w_data[w_idx]
                out_data[oh * Wo * Cout + ow * Cout + co] = acc

    return out_data, out_shape


def relu_tensor(data):
    return [max(0.0, v) for v in data]


def add_tensors(a, b):
    return [a[i] + b[i] for i in range(len(a))]


def maxpool2d(x_data, x_shape, k=3, stride=2, padding=1):
    H, W, C = x_shape
    Ho = (H + 2 * padding - k) // stride + 1
    Wo = (W + 2 * padding - k) // stride + 1
    out_data = [-1e9] * (Ho * Wo * C)
    out_shape = (Ho, Wo, C)
    for oh in range(Ho):
        for ow in range(Wo):
            for c in range(C):
                max_val = -1e9
                for kh in range(k):
                    for kw in range(k):
                        ih = oh * stride - padding + kh
                        iw = ow * stride - padding + kw
                        if 0 <= ih < H and 0 <= iw < W:
                            val = x_data[ih * W * C + iw * C + c]
                            if val > max_val:
                                max_val = val
                out_data[oh * Wo * C + ow * C + c] = max_val
    return out_data, out_shape


def global_avg_pool(x_data, x_shape):
    """(H, W, C) -> flat list of length C"""
    H, W, C = x_shape
    out = [0.0] * C
    for c in range(C):
        s = 0.0
        for h in range(H):
            for w in range(W):
                s += x_data[h * W * C + w * C + c]
        out[c] = s / (H * W)
    return out


def fc_layer(x_data, w_data, in_f, out_f):
    """x: (in_f,), w: (in_f, out_f) flat -> (out_f,)"""
    out = [0.0] * out_f
    for o in range(out_f):
        acc = 0.0
        for i in range(in_f):
            acc += x_data[i] * w_data[i * out_f + o]
        out[o] = acc
    return out


# ============================================================================
# 4. Weight Initialization
# ============================================================================

def he_init_flat(Cout, K, Cin):
    """Kaiming He init: (Cout, K, K, Cin) stored flat."""
    fan_in = K * K * Cin
    std = math.sqrt(2.0 / fan_in)
    size = Cout * K * K * Cin
    return [random.gauss(0, std) for _ in range(size)], (Cout, K, K, Cin)


# ============================================================================
# 5. ResNet-50 Architecture (Scaled Down)
# ============================================================================
# Using 8x8 input (instead of 224x224) to keep simulation fast.
# Architecture: conv1 -> maxpool -> 16 bottleneck blocks -> avgpool -> FC
# Each bottleneck = 3 conv layers + optional downsample = ~50 conv layers total

class ConvOp:
    def __init__(self, Cin, Cout, K, stride=1, padding=0):
        self.w_data, self.w_shape = he_init_flat(Cout, K, Cin)
        self.stride = stride
        self.padding = padding
        self.desc = f"Conv({Cin}->{Cout}, {K}x{K}, s={stride})"

    def run(self, x_data, x_shape, lut=None):
        w = quantize_tensor(self.w_data, lut) if lut else self.w_data
        x = quantize_tensor(x_data, lut) if lut else x_data
        out_data, out_shape = conv2d(x, x_shape, w, self.w_shape, self.stride, self.padding)
        if lut:
            out_data = quantize_tensor(out_data, lut)
        return out_data, out_shape


class BottleneckBlock:
    def __init__(self, Cin, Cmid, Cout, stride=1, downsample=False):
        self.c1 = ConvOp(Cin, Cmid, 1)
        self.c2 = ConvOp(Cmid, Cmid, 3, stride=stride, padding=1)
        self.c3 = ConvOp(Cmid, Cout, 1)
        self.ds = ConvOp(Cin, Cout, 1, stride=stride) if downsample else None

    def run(self, x_data, x_shape, lut=None):
        identity = x_data[:]

        out, sh = self.c1.run(x_data, x_shape, lut)
        out = relu_tensor(out)

        out, sh = self.c2.run(out, sh, lut)
        out = relu_tensor(out)

        out, sh = self.c3.run(out, sh, lut)

        if self.ds:
            identity, _ = self.ds.run(x_data, x_shape, lut)

        out = add_tensors(out, identity)
        if lut:
            out = quantize_tensor(out, lut)
        out = relu_tensor(out)
        return out, sh


# Reduced channel counts to keep pure-Python simulation feasible
# Real ResNet-50: 64/256/512/1024/2048
# Our scaled version: 16/64/128/256/512
# This preserves the architectural structure (bottleneck, skip connections,
# 16 blocks) while keeping each conv operation small enough for Python loops.

SCALE = 4  # divide all channel counts by this factor

def build_resnet50():
    """Build ResNet-50 with reduced channels for pure-Python speed."""
    c1 = 64 // SCALE     # 16
    c1_out = 256 // SCALE # 64
    c2_mid = 128 // SCALE # 32
    c2_out = 512 // SCALE # 128
    c3_mid = 256 // SCALE # 64
    c3_out = 1024 // SCALE# 256
    c4_mid = 512 // SCALE # 128
    c4_out = 2048 // SCALE# 512

    conv1 = ConvOp(3, c1, 3, stride=1, padding=1)  # 3x3 instead of 7x7 for small input

    blocks = []
    names = []

    # Layer 1: 3 blocks
    blocks.append(BottleneckBlock(c1, c1, c1_out, 1, True))
    names.append("L1.B0")
    blocks.append(BottleneckBlock(c1_out, c1, c1_out))
    names.append("L1.B1")
    blocks.append(BottleneckBlock(c1_out, c1, c1_out))
    names.append("L1.B2")

    # Layer 2: 4 blocks
    blocks.append(BottleneckBlock(c1_out, c2_mid, c2_out, 2, True))
    names.append("L2.B0")
    blocks.append(BottleneckBlock(c2_out, c2_mid, c2_out))
    names.append("L2.B1")
    blocks.append(BottleneckBlock(c2_out, c2_mid, c2_out))
    names.append("L2.B2")
    blocks.append(BottleneckBlock(c2_out, c2_mid, c2_out))
    names.append("L2.B3")

    # Layer 3: 6 blocks
    blocks.append(BottleneckBlock(c2_out, c3_mid, c3_out, 2, True))
    names.append("L3.B0")
    blocks.append(BottleneckBlock(c3_out, c3_mid, c3_out))
    names.append("L3.B1")
    blocks.append(BottleneckBlock(c3_out, c3_mid, c3_out))
    names.append("L3.B2")
    blocks.append(BottleneckBlock(c3_out, c3_mid, c3_out))
    names.append("L3.B3")
    blocks.append(BottleneckBlock(c3_out, c3_mid, c3_out))
    names.append("L3.B4")
    blocks.append(BottleneckBlock(c3_out, c3_mid, c3_out))
    names.append("L3.B5")

    # Layer 4: 3 blocks
    blocks.append(BottleneckBlock(c3_out, c4_mid, c4_out, 2, True))
    names.append("L4.B0")
    blocks.append(BottleneckBlock(c4_out, c4_mid, c4_out))
    names.append("L4.B1")
    blocks.append(BottleneckBlock(c4_out, c4_mid, c4_out))
    names.append("L4.B2")

    # FC weights
    fc_in = c4_out   # 512
    fc_out = 100      # reduced from 1000
    fc_w = [random.gauss(0, math.sqrt(2.0 / (fc_in + fc_out))) for _ in range(fc_in * fc_out)]

    return conv1, blocks, names, fc_w, fc_in, fc_out


def run_resnet50(conv1, blocks, names, fc_w, fc_in, fc_out, x_data, x_shape, lut=None, label=""):
    """Run full forward pass. Returns (final_output, per_layer_outputs)."""
    outputs = []
    t_start = time.time()

    # conv1 + ReLU
    x, sh = conv1.run(x_data, x_shape, lut)
    x = relu_tensor(x)
    outputs.append(("conv1", x[:], sh))
    elapsed = time.time() - t_start
    print(f"    [{label}] conv1 done — {sh} ({elapsed:.1f}s)")

    # 16 bottleneck blocks
    for i, (name, block) in enumerate(zip(names, blocks)):
        x, sh = block.run(x, sh, lut)
        outputs.append((name, x[:], sh))
        elapsed = time.time() - t_start
        print(f"    [{label}] {name} done — {sh} ({elapsed:.1f}s)")

    # Global average pooling
    x_vec = global_avg_pool(x, sh)

    # FC layer
    if lut:
        x_vec = quantize_tensor(x_vec, lut)
        fc_w_q = quantize_tensor(fc_w, lut)
        fc_out_vec = fc_layer(x_vec, fc_w_q, fc_in, fc_out)
        fc_out_vec = quantize_tensor(fc_out_vec, lut)
    else:
        fc_out_vec = fc_layer(x_vec, fc_w, fc_in, fc_out)

    outputs.append(("FC", fc_out_vec[:], (fc_out,)))
    elapsed = time.time() - t_start
    print(f"    [{label}] FC done — ({fc_out},) ({elapsed:.1f}s)")

    return fc_out_vec, outputs


# ============================================================================
# 6. Accuracy Metrics
# ============================================================================

def cosine_similarity(a, b):
    dot = sum(ai * bi for ai, bi in zip(a, b))
    na = math.sqrt(sum(ai * ai for ai in a))
    nb = math.sqrt(sum(bi * bi for bi in b))
    if na < 1e-15 or nb < 1e-15:
        return 0.0
    return dot / (na * nb)


def calc_rmse(a, b):
    n = len(a)
    if n == 0: return 0.0
    return math.sqrt(sum((ai - bi) ** 2 for ai, bi in zip(a, b)) / n)


def calc_max_abs_error(a, b):
    return max(abs(ai - bi) for ai, bi in zip(a, b))


# ============================================================================
# 7. Main Simulation
# ============================================================================

def main():
    print("=" * 90)
    print("  ResNet-50 Full-Network Posit Accuracy Simulation (Pure Python)")
    print("  Float32 vs 12-bit Posit (es=1) vs 6-bit Posit (es=1)")
    print("  Input: 8x8x3 | Channels: 1/4 scale | 16 Bottleneck Blocks + FC")
    print("=" * 90)

    # Build posit lookup tables
    print("\n[Step 1] Building posit lookup tables...")
    lut_12 = build_posit_lut(12, 1)
    lut_6 = build_posit_lut(6, 1)
    print(f"  12-bit: {len(lut_12)} values, range [{lut_12[0]:.8f}, {lut_12[-1]:.1f}]")
    print(f"   6-bit: {len(lut_6)} values, range [{lut_6[0]:.8f}, {lut_6[-1]:.1f}]")

    # Build model
    print("\n[Step 2] Building ResNet-50 model (reduced channels)...")
    random.seed(42)
    conv1, blocks, names, fc_w, fc_in, fc_out = build_resnet50()
    print(f"  Model: conv1 + {len(blocks)} bottleneck blocks + FC({fc_in}->{fc_out})")
    total_convs = 1 + sum(4 if b.ds else 3 for b in blocks) + 1
    print(f"  Total conv/fc layers: {total_convs}")

    # Create input image
    random.seed(123)
    H, W, C = 8, 8, 3
    x_data = [random.random() for _ in range(H * W * C)]
    x_shape = (H, W, C)

    # Run Float32
    print(f"\n[Step 3] Running FLOAT32 reference...")
    _, ref_out = run_resnet50(conv1, blocks, names, fc_w, fc_in, fc_out, x_data, x_shape, lut=None, label="FP32")

    # Run 12-bit posit
    print(f"\n[Step 4] Running 12-BIT POSIT...")
    _, p12_out = run_resnet50(conv1, blocks, names, fc_w, fc_in, fc_out, x_data, x_shape, lut=lut_12, label="P12")

    # Run 6-bit posit
    print(f"\n[Step 5] Running 6-BIT POSIT...")
    _, p6_out = run_resnet50(conv1, blocks, names, fc_w, fc_in, fc_out, x_data, x_shape, lut=lut_6, label="P6")

    # Results
    print("\n" + "=" * 90)
    print("  LAYER-BY-LAYER ACCURACY vs FLOAT32 REFERENCE")
    print("=" * 90)
    hdr = f"{'Layer':<10} {'Shape':<14} {'12b CosSim':>11} {'12b RMSE':>10} {'6b CosSim':>11} {'6b RMSE':>10} {'6b MaxErr':>10}"
    print(hdr)
    print("-" * 90)

    for i in range(len(ref_out)):
        name = ref_out[i][0]
        ref = ref_out[i][1]
        p12 = p12_out[i][1]
        p6 = p6_out[i][1]

        cs12 = cosine_similarity(ref, p12)
        cs6 = cosine_similarity(ref, p6)
        r12 = calc_rmse(ref, p12)
        r6 = calc_rmse(ref, p6)
        me6 = calc_max_abs_error(ref, p6)

        sh = ref_out[i][2]
        shape_str = "x".join(str(s) for s in sh)
        print(f"{name:<10} {shape_str:<14} {cs12:>11.6f} {r12:>10.4f} {cs6:>11.6f} {r6:>10.4f} {me6:>10.4f}")

    # Final summary
    print("\n" + "=" * 90)
    print("  FINAL CLASSIFICATION OUTPUT COMPARISON")
    print("=" * 90)
    ref_fc = ref_out[-1][1]
    p12_fc = p12_out[-1][1]
    p6_fc = p6_out[-1][1]

    print(f"  12-bit — Cosine Similarity: {cosine_similarity(ref_fc, p12_fc):.8f}")
    print(f"           RMSE:              {calc_rmse(ref_fc, p12_fc):.6f}")
    print(f"           Max Abs Error:     {calc_max_abs_error(ref_fc, p12_fc):.6f}")
    print()
    print(f"   6-bit — Cosine Similarity: {cosine_similarity(ref_fc, p6_fc):.8f}")
    print(f"           RMSE:              {calc_rmse(ref_fc, p6_fc):.6f}")
    print(f"           Max Abs Error:     {calc_max_abs_error(ref_fc, p6_fc):.6f}")

    # Top-5 predictions
    ref_sorted = sorted(range(len(ref_fc)), key=lambda i: ref_fc[i], reverse=True)[:5]
    p12_sorted = sorted(range(len(p12_fc)), key=lambda i: p12_fc[i], reverse=True)[:5]
    p6_sorted = sorted(range(len(p6_fc)), key=lambda i: p6_fc[i], reverse=True)[:5]

    print(f"\n  TOP-5 CLASS PREDICTIONS:")
    print(f"  Float32: {ref_sorted}")
    print(f"  12-bit:  {p12_sorted}")
    print(f"   6-bit:  {p6_sorted}")

    top1_12 = "MATCH" if ref_sorted[0] == p12_sorted[0] else "MISMATCH"
    top1_6 = "MATCH" if ref_sorted[0] == p6_sorted[0] else "MISMATCH"
    overlap_12 = len(set(ref_sorted) & set(p12_sorted))
    overlap_6 = len(set(ref_sorted) & set(p6_sorted))

    print(f"\n  12-bit: Top-1 {top1_12}, Top-5 Overlap: {overlap_12}/5")
    print(f"   6-bit: Top-1 {top1_6}, Top-5 Overlap: {overlap_6}/5")
    print("=" * 90)


if __name__ == "__main__":
    main()
