# =============================================================================
# verify_back_to_back_tiles.py
# -----------------------------------------------------------------------------
# Measures the EXACT cycle gap between consecutive 64x64 GEMM tiles in a single
# continuous simulation run (no resets between tiles).
# =============================================================================
import os
import sys
import subprocess
from dla_compiler import DLACompiler

def main():
    print("=" * 80)
    print("  Empirical Multi-Tile Back-to-Back Cycle Measurement")
    print("=" * 80)

    compiler = DLACompiler()
    # Generate 1 tile program hex
    _, prog_hex_1tile = compiler.compile_conv_layer(
        h=8, w=8, c=64, kh=1, kw=1, stride=1, padding=0,
        out_channels=64, use_relu=False, simd_mode=False
    )

    # Populate input_a.txt and input_b.txt with 3 tiles worth of matrix data
    with open("input_a.txt", "w") as f:
        for _ in range(3 * 512):
            f.write("001000100010001000100010\n")
    with open("input_b.txt", "w") as f:
        for _ in range(3 * 512):
            f.write("001000100010001000100010\n")

    # Repeat the instruction sequence 3 times continuously for 3 consecutive tiles
    lines_1tile = [line.strip() for line in prog_hex_1tile.strip().split("\n") if line.strip() and not line.startswith("#")]
    
    # Write multi-tile program
    with open("dla_program.hex", "w") as f:
        for tile_id in range(3):
            for line in lines_1tile:
                f.write(line + "\n")

    print("[DEBUG] Generated dla_program.hex for 3 consecutive GEMM tiles back-to-back.")

    # Re-compile Verilog testbench
    src_files = [
        "dla_tb.v", "dla_axi_wrapper.v", "dla_top.v", "dla_controller.v",
        "posit_mxu.v", "posit_mac_array.v", "posit_pe.v", "posit_decode.v", "posit_encode.v",
        "posit_add.v", "posit_mult.v",
        "strassen_top.v", "strassen_preprocess.v", "strassen_scratchpad.v", "strassen_controller.v",
        "fixed_to_posit_conv_8b.v", "posit_add_simd.v",
        "vector_add.v", "vector_activation.v",
        "fixed_add_simd.v", "fixed_add_simd_bank.v",
        "fixed_to_decoded_conv.v", "posit_to_fixed_conv_8b.v", "dla_sram.v", "dla_dma_controller.v"
    ]
    cmd = ["iverilog", "-g2012", "-DSIMULATION", "-DNUM_WORDS=2048", "-I", ".", "-o", "dla_multi_sim.vvp"] + src_files
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode != 0:
        print(f"[ERR] iverilog compilation failed:\n{res.stderr}")
        return

    print("[DEBUG] Executing 3-tile back-to-back hardware simulation in vvp...")
    res = subprocess.run(["vvp", "dla_multi_sim.vvp"], capture_output=True, text=True)
    
    print("\n================================================================================")
    print("  MEASURED HARDWARE LOG OUTPUT (CYCLE TIMESTAMPS)")
    print("================================================================================")
    for line in res.stdout.split("\n"):
        if "CYCLES" in line or "PURE_COMPUTE" in line or "Tile Finished" in line or "SUCCESS" in line:
            print(" ", line)
    print("================================================================================")

if __name__ == "__main__":
    main()
