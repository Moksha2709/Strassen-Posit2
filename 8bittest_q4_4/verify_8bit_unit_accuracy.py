# =============================================================================
# verify_8bit_unit_accuracy.py — Single 8-Bit Q4.4 Unit Benchmark & Unit Tests
# =============================================================================
# Evaluates 100% TRUE RTL Verilog Hardware Accuracy for the 8-Bit Q4.4 Strassen DLA Unit.
# Runs unit tests on Q4.4 fixed-point encoding/decoding and executes a 16x16 hardware tile.
# =============================================================================
import os
import sys
import math
import random
import unittest
import numpy as np

from verify_8bit_resnet_hardware import (
    compile_verilog_netlist, run_one_16x16_tile, encode_fixed8, decode_fixed8
)

class TestQ44Format(unittest.TestCase):
    """Unit test suite for 8-bit Q4.4 fixed-point quantization encoding and decoding."""

    def test_zero_encoding(self):
        """Test encoding and decoding of 0.0."""
        enc = encode_fixed8(0.0)
        dec = decode_fixed8(enc)
        self.assertEqual(enc, 0x00)
        self.assertAlmostEqual(dec, 0.0, places=4)

    def test_positive_integer_encoding(self):
        """Test encoding and decoding of 1.0 (expected = 16 = 0x10)."""
        enc = encode_fixed8(1.0)
        dec = decode_fixed8(enc)
        self.assertEqual(enc, 0x10)
        self.assertAlmostEqual(dec, 1.0, places=4)

    def test_negative_integer_encoding(self):
        """Test encoding and decoding of -1.0 (expected = -16 = 0xf0)."""
        enc = encode_fixed8(-1.0)
        dec = decode_fixed8(enc)
        self.assertEqual(enc, 0xf0)
        self.assertAlmostEqual(dec, -1.0, places=4)

    def test_fractional_encoding(self):
        """Test encoding and decoding of 0.5 (expected = 8 = 0x08)."""
        enc = encode_fixed8(0.5)
        dec = decode_fixed8(enc)
        self.assertEqual(enc, 0x08)
        self.assertAlmostEqual(dec, 0.5, places=4)

    def test_clamping_max(self):
        """Test clamping of values exceeding maximum representable range (> +7.9375)."""
        enc = encode_fixed8(10.0)
        dec = decode_fixed8(enc)
        self.assertEqual(enc, 0x7f) # Max signed 8-bit = 127
        self.assertAlmostEqual(dec, 7.9375, places=4)

    def test_clamping_min(self):
        """Test clamping of values below minimum representable range (< -8.0)."""
        enc = encode_fixed8(-12.0)
        dec = decode_fixed8(enc)
        self.assertEqual(enc, 0x80) # Min signed 8-bit = -128
        self.assertAlmostEqual(dec, -8.0, places=4)


def generate_random_matrix(rows, cols, min_val=-2.0, max_val=2.0, seed=42):
    random.seed(seed)
    return [[random.uniform(min_val, max_val) for _ in range(cols)] for _ in range(rows)]

def matmul_fp32(A, B):
    M = len(A)
    K = len(A[0])
    N = len(B[0])
    C = [[0.0] * N for _ in range(M)]
    for i in range(M):
        for k in range(K):
            a_val = A[i][k]
            for j in range(N):
                C[i][j] += a_val * B[k][j]
    return C

def compute_accuracy_metrics(pred_matrix, ref_matrix):
    pred = np.array(pred_matrix, dtype=np.float32).flatten()
    ref = np.array(ref_matrix, dtype=np.float32).flatten()

    dot_product = np.dot(pred, ref)
    norm_pred = np.linalg.norm(pred)
    norm_ref = np.linalg.norm(ref)

    if norm_pred == 0 or norm_ref == 0:
        cosine_sim = 0.0
    else:
        cosine_sim = float(dot_product / (norm_pred * norm_ref))

    mse = np.mean((pred - ref) ** 2)
    rmse = float(np.sqrt(mse))

    signal_power = np.mean(ref ** 2)
    noise_power = mse

    if noise_power == 0:
        sqnr_db = 100.0
    elif signal_power == 0:
        sqnr_db = -100.0
    else:
        sqnr_db = float(10 * np.log10(signal_power / noise_power))

    return cosine_sim, sqnr_db, rmse

def main():
    print("=" * 80)
    print("      8-BIT Q4.4 STRASSEN DLA: SINGLE-UNIT ACCURACY & ENCODING AUDIT")
    print("=" * 80)

    # 1. Run Python Q4.4 Format Unit Tests
    print("\n[1/4] Running 8-Bit Q4.4 Format Functionality Unit Tests...")
    suite = unittest.TestLoader().loadTestsFromTestCase(TestQ44Format)
    runner = unittest.TextTestRunner(verbosity=1)
    test_result = runner.run(suite)
    if not test_result.wasSuccessful():
        print("[ERR] Q4.4 Unit Tests failed!")
        sys.exit(1)

    TILE_SIZE = 16

    print(f"\n[2/4] Generating random FP32 matrix pair (Tile Size: {TILE_SIZE}x{TILE_SIZE})...")
    a = generate_random_matrix(TILE_SIZE, TILE_SIZE, min_val=-2.0, max_val=2.0, seed=123)
    b = generate_random_matrix(TILE_SIZE, TILE_SIZE, min_val=-2.0, max_val=2.0, seed=456)

    print("[3/4] Computing FP32 Ground Truth...")
    c_ref = matmul_fp32(a, b)

    print("[4/4] Compiling Verilog RTL source files (.v) on the fly & executing tile simulation...")
    sim_bin = compile_verilog_netlist("temp_8bit_unit_sim.vvp")
    try:
        c_hw = run_one_16x16_tile(a, b, sim_bin=sim_bin)
    finally:
        if os.path.exists(sim_bin):
            os.remove(sim_bin)

    cosine_sim, sqnr_db, rmse = compute_accuracy_metrics(c_hw, c_ref)

    print("\n" + "=" * 80)
    print("                 8-BIT Q4.4 UNIT ACCURACY RESULTS")
    print("=" * 80)
    print(f"  Single 16x16 Tile -> Cosine Sim: {cosine_sim:.6f} | SQNR: {sqnr_db:6.2f} dB | RMSE: {rmse:.5f}")
    print("=" * 80 + "\n")

if __name__ == "__main__":
    main()
