# =============================================================================
# compare_paper_counts_opti.py — Paper Metrics Comparison Table (test8opti)
# =============================================================================

def print_paper_comparison():
    print("=" * 115)
    print("  COMPREHENSIVE STRASSEN PAPER BENCHMARK COMPARISON TABLE (IEEE TC / TVLSI)")
    print("=" * 115)

    rows = [
        ("Reference Paper (SMM1 Table II)", "Arria 10 GX1150", 1518, "~306,000", 293.0, "2.18 ms", "3,750.0 GOPS", "0.877"),
        ("Reference Paper (SMM2 Table II)", "Arria 10 GX1150", 1518, "~145,000", 295.0, "4.04 ms", "2,024.0 GOPS", "1.051"),
        ("16-Bit Fixed Baseline (16bittest)", "Zynq UltraScale+", 448, "53,269", 419.8, "124.60 ms", "65.6 GOPS", "1.143"),
        ("Unoptimized Posit8 (test8bit)", "Zynq UltraScale+", 448, "306,331", 264.1, "118.82 ms", "68.8 GOPS", "3.429"),
        ("Our Optimized Posit8 (test8opti)", "Zynq UltraScale+", 448, "173,833", 322.7, "97.26 ms", "84.0 GOPS", "3.429"),
        ("Our Design Scaled (1,518 DSPs)", "Zynq UltraScale+", 1518, "~588,000", 322.7, "28.70 ms", "284.8 GOPS", "3.429"),
    ]

    print(f"{'Design Configuration':<36} | {'Target FPGA':<16} | {'DSPs':<5} | {'LUTs':<9} | {'Freq (MHz)':<10} | {'ResNet Time':<11} | {'Throughput':<12} | {'MCE':<6}")
    print("-" * 115)
    for r in rows:
        print(f"{r[0]:<36} | {r[1]:<16} | {r[2]:<5} | {r[3]:<9} | {r[4]:<10.1f} | {r[5]:<11} | {r[6]:<12} | {r[7]:<6}")
    print("-" * 115 + "\n")

if __name__ == "__main__":
    print_paper_comparison()
