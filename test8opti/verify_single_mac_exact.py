import math
import random
from verify_mobilenet_accuracy import encode_posit8, decode_posit_n_es, POSIT_WIDTH

def main():
    print("=" * 80)
    print("        SINGLE-MAC ARITHMETIC CORRECTNESS & CARRIER AUDIT")
    print("=" * 80)

    # Let's audit 1,000 random MAC accumulators of length K=64
    random.seed(42)
    
    total_abs_err_float = 0.0
    total_abs_err_exact_posit = 0.0
    ref_power = 0.0
    
    for trial in range(1000):
        # 64-element vectors
        a_floats = [random.uniform(-1.0, 1.0) for _ in range(64)]
        w_floats = [random.uniform(-1.0, 1.0) for _ in range(64)]
        
        # Float32 ground truth
        float32_mac = sum(a * w for a, w in zip(a_floats, w_floats))
        
        # Posit8 quantized inputs
        a_posits = [encode_posit8(a) for a in a_floats]
        w_posits = [encode_posit8(w) for w in w_floats]
        
        a_decoded = [decode_posit_n_es(b, POSIT_WIDTH, 1) for b in a_posits]
        w_decoded = [decode_posit_n_es(b, POSIT_WIDTH, 1) for b in w_posits]
        
        # Exact Posit MAC (using exact floating-point addition of decoded Posits)
        exact_posit_mac = sum(ad * wd for ad, wd in zip(a_decoded, w_decoded))
        
        # Quantized Posit output
        posit_out_code = encode_posit8(exact_posit_mac)
        posit_out_val = decode_posit_n_es(posit_out_code, POSIT_WIDTH, 1)
        
        total_abs_err_float += (posit_out_val - float32_mac)**2
        total_abs_err_exact_posit += (exact_posit_mac - float32_mac)**2
        ref_power += float32_mac**2

    rmse_vs_float = math.sqrt(total_abs_err_float / 1000)
    rmse_exact_posit = math.sqrt(total_abs_err_exact_posit / 1000)
    rms_ref = math.sqrt(ref_power / 1000)
    
    rel_err_quantized = (rmse_vs_float / rms_ref) * 100.0
    rel_err_exact_mac = (rmse_exact_posit / rms_ref) * 100.0
    
    print(f"  Reference Float32 RMS     : {rms_ref:.5f}")
    print(f"  Exact Posit MAC RMSE (Quire): {rmse_exact_posit:.5f} ({rel_err_exact_mac:.2f}% rel err vs Float32)")
    print(f"  Quantized 8-Bit Posit RMSE  : {rmse_vs_float:.5f} ({rel_err_quantized:.2f}% rel err vs Float32)")
    print("=" * 80 + "\n")

if __name__ == "__main__":
    main()
