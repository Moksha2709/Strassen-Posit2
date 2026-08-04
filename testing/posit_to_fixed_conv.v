// =============================================================================
// posit_to_fixed_conv.v — Verilog
// Unified Dynamic Boundary Posit-to-Fixed Converter
// Converts raw Posit (12-bit or dual 6-bit SIMD) to Fixed-Point
// =============================================================================
`include "posit_pkg.vh"

module posit_to_fixed_conv (
    input  wire [11:0] in,        // Raw input posit
    output reg  [31:0] out        // Decoded & converted Fixed-Point format
                                  // [31:16] = 16'b0, [15:0] = 16-bit fixed-point (Q8.8)
);

    // =========================================================================
    // 1. Unified Decoding Logic (Single reconfigurable block)
    // =========================================================================
    
    // --- Sign Extraction ---
    wire sign_12b;
    
    assign sign_12b  = in[11];

    // --- Absolute Value of Body ---
    wire [11:0] in_abs_12b;

    assign in_abs_12b  = sign_12b ? (-in) : in;

    // --- Special Cases Check ---
    wire is_zero_12b, is_nar_12b;

    assign is_zero_12b  = (in == 12'b0);
    assign is_nar_12b   = (in == 12'h800);

    // --- Unified Leading Zero Detector (LZD) ---
    // In 12-bit mode, we search in_abs_12b[10:0].
    wire [10:0] lzd_in_12b = in_abs_12b[10:0] ^ {11{in_abs_12b[10]}};

    reg [3:0] lz_12b;
    always @(*) begin
        lz_12b = 
            lzd_in_12b[10] ? 4'd0 :
            lzd_in_12b[9]  ? 4'd1 :
            lzd_in_12b[8]  ? 4'd2 :
            lzd_in_12b[7]  ? 4'd3 :
            lzd_in_12b[6]  ? 4'd4 :
            lzd_in_12b[5]  ? 4'd5 :
            lzd_in_12b[4]  ? 4'd6 :
            lzd_in_12b[3]  ? 4'd7 :
            lzd_in_12b[2]  ? 4'd8 :
            lzd_in_12b[1]  ? 4'd9 :
            lzd_in_12b[0]  ? 4'd10 : 4'd11;
    end

    // --- Regime & Exponent values ---
    reg [4:0] k_12b;
    reg signed [5:0] regime_12b;

    always @(*) begin
        // 12-bit regime
        k_12b = (lz_12b > 4'd6) ? 5'd6 : {1'b0, lz_12b};
        if (in_abs_12b[10])
            regime_12b = $signed({1'b0, k_12b}) - 1;
        else
            regime_12b = -$signed({1'b0, k_12b});
    end

    // --- Body Shifter ---
    reg [10:0] body_shifted_12b;

    always @(*) begin
        body_shifted_12b  = in_abs_12b[10:0] << (k_12b + 1);
    end

    // --- Scale and Fraction Assembly ---
    wire signed [6:0] scale_12b;
    wire [11:0]       frac_12b;

    assign scale_12b = (regime_12b * 2) + $signed({6'b0, body_shifted_12b[10]}); // ES=1
    assign frac_12b  = {1'b1, body_shifted_12b[9:0], 1'b0};

    // =========================================================================
    // 2. Posit to Fixed-Point Conversion (Shifters)
    // =========================================================================
    
    // --- 12-bit Posit to 16-bit Fixed-Point (Q8.8) ---
    // target fixed value = frac * 2^(scale + 8 - 11) = frac * 2^(scale - 3)
    reg [31:0] shifted_frac_12b;
    wire signed [6:0] shift_amt_12b = scale_12b - 7'sd3;
    always @(*) begin
        if (shift_amt_12b >= 0) begin
            if (shift_amt_12b >= 16)
                shifted_frac_12b = 32'b0;
            else
                shifted_frac_12b = {20'b0, frac_12b} << shift_amt_12b;
        end else begin
            if (-shift_amt_12b >= 16)
                shifted_frac_12b = 32'b0;
            else
                shifted_frac_12b = {20'b0, frac_12b} >> (-shift_amt_12b);
        end
    end

    wire [15:0] abs_fixed_12b = shifted_frac_12b[15:0];
    wire [15:0] final_fixed_12b = sign_12b ? (-abs_fixed_12b) : abs_fixed_12b;

    // =========================================================================
    // 3. Output Multiplexer
    // =========================================================================
    always @(*) begin
        out[31:16] = 16'b0;
        out[15:0]  = (is_zero_12b || is_nar_12b) ? 16'b0 : final_fixed_12b;
    end

endmodule
