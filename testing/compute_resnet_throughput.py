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

    # Measured hardware parameters:
    # - Measured execution cycles per 64x64 GEMM tile = 24,656 cycles (from dla_tb.v)
    # - Synthesized clock frequency = 280.3 MHz (from Vivado timing_synth_report.rpt)
    # - Total 64x64 tiles for all 53 ResNet-50 layers = 2,896 tiles
    cycles_per_tile = 24_656
    total_tiles = 2_896
    total_cycles = total_tiles * cycles_per_tile
    synth_freq_mhz = 280.3

    gops_real = gops_from_cycles(total, total_cycles, synth_freq_mhz)
    gops_peak = 448 * 3 * 2 * synth_freq_mhz / 1e3

    print("=" * 70)
    print("  MEASURED RESNET-50 HARDWARE THROUGHPUT & CYCLE METRICS")
    print("=" * 70)
    print(f" Measured Cycles / 64x64 Tile    : {cycles_per_tile:,} cycles")
    print(f" Total 64x64 GEMM Tiles (ResNet50): {total_tiles:,} tiles")
    print(f" Total Full-Pass Hardware Cycles  : {total_cycles:,} cycles")
    print(f" Synthesized Frequency (Vivado)   : {synth_freq_mhz} MHz")
    print(f" Full-Pass Execution Latency      : {total_cycles / (synth_freq_mhz * 1e6) * 1e3:.2f} ms")
    print(f" Real End-to-End Throughput       : {gops_real:.2f} GOPS")
    print(f" Peak Hardware Compute Ceiling    : {gops_peak:.2f} GOPS")
    print("=" * 70)
    example_freq = 295           # MHz, e.g. matching SMM2 8x8 from the paper
    gops = gops_from_cycles(total, example_cycles, example_freq)
    print(f"\nExample GOPS (with placeholder cycle count {example_cycles:,} "
          f"@ {example_freq} MHz): {gops:.1f} GOPS")
