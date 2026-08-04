# =============================================================================
# compare_paper_counts.py — Comprehensive Benchmark Comparison Script
# -----------------------------------------------------------------------------
# Compares all design variations: Reference Paper (TVLSI 2025), Pure DSP Paper
# Heuristic (test8bit_paper_heuristic), Our Design (test8bit), and Scaled Design.
# =============================================================================

def print_comprehensive_comparison():
    print("=" * 105)
    print("  COMPREHENSIVE HARDWARE BENCHMARK COMPARISON TABLE")
    print("=" * 105)

    headers = [
        "Design Configuration", "Target FPGA", "DSPs", "LUTs", "Freq (MHz)",
        "ResNet-50 Time", "ResNet-50 GOPS", "Peak Roof", "MCE (mults/DSP/cyc)"
    ]

    rows = [
        ("Reference Paper (SMM1 Table II)", "Arria 10 GX1150", 1518, "~306,000", 293.0, "2.18 ms", "3,750.0", "4,276.0", "0.877"),
        ("Reference Paper (SMM2 Table II)", "Arria 10 GX1150", 1518, "~145,000", 295.0, "4.04 ms", "2,024.0", "2,158.0", "1.051"),
        ("Pure DSP Paper Heuristic (test8bit_paper)", "Zynq UltraScale+", 448, "~245,000", 280.3, "111.97 ms", "73.0", "753.4", "3.420 (Approx)"),
        ("Our 8-Bit Triple Posit DLA (test8bit)", "Zynq UltraScale+", 448, "247,169", 280.3, "111.97 ms", "73.0", "753.5", "3.420 (Bit-Exact)"),
        ("Our Design Scaled (Equal 1,518 DSPs)", "Zynq UltraScale+", 1518, "~837,000", 280.3, "33.05 ms", "247.4", "2,553.0", "3.420 (Bit-Exact)"),
        ("Our Design Hybrid FFIP (1,518 DSPs)", "Zynq UltraScale+", 1518, "~837,000", 280.3, "14.50 ms", "563.7", "5,820.8", "6.840 (Hybrid Ceiling)"),
    ]

    print("-" * 105)
    print(f"{'Design Configuration':<38} | {'DSPs':<5} | {'LUTs':<10} | {'Freq':<7} | {'ResNet Time':<11} | {'ResNet GOPS':<11} | {'MCE':<6}")
    print("-" * 105)
    for r in rows:
        print(f"{r[0]:<38} | {r[2]:<5} | {r[3]:<10} | {r[4]:<7.1f} | {r[5]:<11} | {r[6]:<11} | {r[8]:<6}")
    print("-" * 105 + "\n")

if __name__ == "__main__":
    print_comprehensive_comparison()
