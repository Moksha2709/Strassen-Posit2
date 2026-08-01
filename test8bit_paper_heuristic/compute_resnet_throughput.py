# =============================================================================
# compute_resnet_throughput.py — Computes total real-ResNet-50 multiply count
# and GOPS/MCE the same way Table II of the paper does, using real layer
# shapes pulled from torchvision (not synthetic ones).
#
# GOPS in the paper = (multiplications required by conventional algebra)
#                      / (measured execution time)
# This script gives you the numerator (the multiply count) for real
# ResNet-50/101/152. You still need the denominator (execution time / cycle
# count) from your own hardware simulation or timing model to get GOPS.
# =============================================================================
from resnet_layer_extractor import get_resnet50_conv_layers


def conv_layer_multiplies(spec):
    """Standard multiply count for one conv layer using conventional algebra:
    out_H * out_W * out_C * in_C * kH * kW"""
    C_in, H_in, W_in = spec["input"].shape
    out_C, _, kH, kW = spec["weight"].shape
    sH, sW = spec["stride"]
    pH, pW = spec["padding"]

    out_H = (H_in + 2 * pH - kH) // sH + 1
    out_W = (W_in + 2 * pW - kW) // sW + 1

    return out_H * out_W * out_C * C_in * kH * kW, (out_H, out_W, out_C)


def total_resnet50_multiplies(pretrained=True):
    layers = get_resnet50_conv_layers(pretrained=pretrained)
    total = 0
    breakdown = []
    for spec in layers:
        mults, out_shape = conv_layer_multiplies(spec)
        total += mults
        breakdown.append((spec["name"], mults, out_shape))
    return total, breakdown


def gops_from_cycles(total_mults, cycles, freq_mhz):
    """Matches the paper's GOPS metric: total conventional multiplications
    (as a proxy for total ops) divided by execution time.
    cycles: total clock cycles measured/estimated for one forward pass
    freq_mhz: clock frequency in MHz"""
    exec_time_s = cycles / (freq_mhz * 1e6)
    gops = (total_mults * 2) / exec_time_s / 1e9  # x2: MAC = 1 mult + 1 add = 2 ops
    return gops


if __name__ == "__main__":
    total, breakdown = total_resnet50_multiplies(pretrained=False)
    print(f"Total multiplications for one ResNet-50 forward pass (224x224 input): "
          f"{total:,}\n")
    print(f"{'layer':<28} {'multiplies':>14} {'out shape':>18}")
    for name, mults, out_shape in breakdown[:10]:
        print(f"{name:<28} {mults:>14,} {out_shape!s:>18}")
    print("...")

    # Example: plug in a cycle count from your simulation to get GOPS
    example_cycles = 5_000_000   # <-- replace with your measured/estimated cycles
    example_freq = 295           # MHz, e.g. matching SMM2 8x8 from the paper
    gops = gops_from_cycles(total, example_cycles, example_freq)
    print(f"\nExample GOPS (with placeholder cycle count {example_cycles:,} "
          f"@ {example_freq} MHz): {gops:.1f} GOPS")
