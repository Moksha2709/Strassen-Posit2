// =============================================================================
// posit_to_fixed_conv.v — Verilog
// Unified Dynamic Boundary Posit-to-Fixed Converter
// Converts raw Posit (12-bit or dual 6-bit SIMD) to Fixed-Point
// =============================================================================
`include "posit_pkg.vh"

module posit_to_fixed_conv (
    input  wire        simd_mode, // 0 = 12-bit mode, 1 = dual 6-bit SIMD mode
    input  wire [11:0] in,        // Raw input posit
    output reg  [31:0] out        // Decoded & converted Fixed-Point format
                                  // simd_mode=0: [31:16] = 16'b0, [15:0] = 16-bit fixed-point (Q8.8)
                                  // simd_mode=1: [31:16] = High 16-bit fixed (padded Q4.4), [15:0] = Low 16-bit fixed (padded Q4.4)
);

    // =========================================================================
    // 1. Unified Decoding Logic (Single reconfigurable block)
    // =========================================================================
    
    // --- Sign Extraction ---
    wire sign_12b;
    wire sign_6b_h;
    wire sign_6b_l;
    
    assign sign_12b  = in[11];
    assign sign_6b_h = in[11];
    assign sign_6b_l = in[5];

    // --- Absolute Value of Body ---
    wire [11:0] in_abs_12b;
    wire [5:0]  in_abs_6b_h;
    wire [5:0]  in_abs_6b_l;

    assign in_abs_12b  = sign_12b ? (-in) : in;
    assign in_abs_6b_h = sign_6b_h ? (-in[11:6]) : in[11:6];
    assign in_abs_6b_l = sign_6b_l ? (-in[5:0]) : in[5:0];

    // --- Special Cases Check ---
    wire is_zero_12b, is_nar_12b;
    wire is_zero_6b_h, is_nar_6b_h;
    wire is_zero_6b_l, is_nar_6b_l;

    assign is_zero_12b  = (in == 12'b0);
    assign is_nar_12b   = (in == 12'h800);
    
    assign is_zero_6b_h = (in[11:6] == 6'b0);
    assign is_nar_6b_h  = (in[11:6] == 6'b100000);
    
    assign is_zero_6b_l = (in[5:0] == 6'b0);
    assign is_nar_6b_l  = (in[5:0] == 6'b100000);

    // --- Unified Leading Zero Detector (LZD) ---
    // In 12-bit mode, we search in_abs_12b[10:0].
    // In 6-bit mode, we search in_abs_6b_h[4:0] and in_abs_6b_l[4:0].
    wire [10:0] lzd_in_12b = in_abs_12b[10:0] ^ {11{in_abs_12b[10]}};
    wire [4:0]  lzd_in_6b_h = in_abs_6b_h[4:0] ^ {5{in_abs_6b_h[4]}};
    wire [4:0]  lzd_in_6b_l = in_abs_6b_l[4:0] ^ {5{in_abs_6b_l[4]}};

    // Hierarchical LZD Tree Tap
    wire [2:0] lz_low;
    assign lz_low = 
        lzd_in_6b_l[4] ? 3'd0 :
        lzd_in_6b_l[3] ? 3'd1 :
        lzd_in_6b_l[2] ? 3'd2 :
        lzd_in_6b_l[1] ? 3'd3 :
        lzd_in_6b_l[0] ? 3'd4 : 3'd5;

    wire [2:0] lz_high;
    assign lz_high = 
        lzd_in_6b_h[4] ? 3'd0 :
        lzd_in_6b_h[3] ? 3'd1 :
        lzd_in_6b_h[2] ? 3'd2 :
        lzd_in_6b_h[1] ? 3'd3 :
        lzd_in_6b_h[0] ? 3'd4 : 3'd5;

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
    reg [4:0] k_6b_h;
    reg signed [5:0] regime_6b_h;
    reg [4:0] k_6b_l;
    reg signed [5:0] regime_6b_l;

    always @(*) begin
        // 12-bit regime
        k_12b = (lz_12b > 4'd6) ? 5'd6 : {1'b0, lz_12b};
        if (in_abs_12b[10])
            regime_12b = $signed({1'b0, k_12b}) - 1;
        else
            regime_12b = -$signed({1'b0, k_12b});

        // 6-bit high regime
        k_6b_h = (lz_high > 3'd4) ? 5'd4 : {2'b0, lz_high};
        if (in_abs_6b_h[4])
            regime_6b_h = $signed({1'b0, k_6b_h}) - 1;
        else
            regime_6b_h = -$signed({1'b0, k_6b_h});

        // 6-bit low regime
        k_6b_l = (lz_low > 3'd4) ? 5'd4 : {2'b0, lz_low};
        if (in_abs_6b_l[4])
            regime_6b_l = $signed({1'b0, k_6b_l}) - 1;
        else
            regime_6b_l = -$signed({1'b0, k_6b_l});
    end

    // --- Body Shifter ---
    reg [10:0] body_shifted_12b;
    reg [4:0]  body_shifted_6b_h;
    reg [4:0]  body_shifted_6b_l;

    always @(*) begin
        body_shifted_12b  = in_abs_12b[10:0] << (k_12b + 1);
        body_shifted_6b_h = in_abs_6b_h[4:0] << (k_6b_h + 1);
        body_shifted_6b_l = in_abs_6b_l[4:0] << (k_6b_l + 1);
    end

    // --- Scale and Fraction Assembly ---
    wire signed [6:0] scale_12b;
    wire [11:0]       frac_12b;
    
    wire signed [6:0] scale_6b_h;
    wire [5:0]        frac_6b_h;
    
    wire signed [6:0] scale_6b_l;
    wire [5:0]        frac_6b_l;

    assign scale_12b = (regime_12b * 2) + $signed({6'b0, body_shifted_12b[10]}); // ES=1
    assign frac_12b  = {1'b1, body_shifted_12b[9:0], 1'b0};

    assign scale_6b_h = (regime_6b_h * 2) + $signed({6'b0, body_shifted_6b_h[4]}); // ES=1
    assign frac_6b_h  = {1'b1, body_shifted_6b_h[3:0], 1'b0};

    assign scale_6b_l = (regime_6b_l * 2) + $signed({6'b0, body_shifted_6b_l[4]}); // ES=1
    assign frac_6b_l  = {1'b1, body_shifted_6b_l[3:0], 1'b0};

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

    // --- 6-bit Posit High to 16-bit Fixed (Q4.4 padded to 16-bit) ---
    // target fixed value = frac * 2^(scale + 4 - 5) = frac * 2^(scale - 1)
    reg [15:0] shifted_frac_6b_h;
    wire signed [6:0] shift_amt_6b_h = scale_6b_h - 7'sd1;
    always @(*) begin
        if (shift_amt_6b_h >= 0) begin
            if (shift_amt_6b_h >= 8)
                shifted_frac_6b_h = 16'b0;
            else
                shifted_frac_6b_h = {10'b0, frac_6b_h} << shift_amt_6b_h;
        end else begin
            if (-shift_amt_6b_h >= 8)
                shifted_frac_6b_h = 16'b0;
            else
                shifted_frac_6b_h = {10'b0, frac_6b_h} >> (-shift_amt_6b_h);
        end
    end
    wire [7:0] abs_fixed_6b_h = shifted_frac_6b_h[7:0];
    // Pad to 16-bit signed
    wire [15:0] final_fixed_6b_h = sign_6b_h ? {8'hFF, -abs_fixed_6b_h} : {8'h00, abs_fixed_6b_h};

    // --- 6-bit Posit Low to 16-bit Fixed (Q4.4 padded to 16-bit) ---
    reg [15:0] shifted_frac_6b_l;
    wire signed [6:0] shift_amt_6b_l = scale_6b_l - 7'sd1;
    always @(*) begin
        if (shift_amt_6b_l >= 0) begin
            if (shift_amt_6b_l >= 8)
                shifted_frac_6b_l = 16'b0;
            else
                shifted_frac_6b_l = {10'b0, frac_6b_l} << shift_amt_6b_l;
        end else begin
            if (-shift_amt_6b_l >= 8)
                shifted_frac_6b_l = 16'b0;
            else
                shifted_frac_6b_l = {10'b0, frac_6b_l} >> (-shift_amt_6b_l);
        end
    end
    wire [7:0] abs_fixed_6b_l = shifted_frac_6b_l[7:0];
    wire [15:0] final_fixed_6b_l = sign_6b_l ? {8'hFF, -abs_fixed_6b_l} : {8'h00, abs_fixed_6b_l};

    // --- Output Multiplexer ---
    always @(*) begin
        if (simd_mode) begin
            out[31:16] = (is_zero_6b_h || is_nar_6b_h) ? 16'b0 : final_fixed_6b_h;
            out[15:0]  = (is_zero_6b_l || is_nar_6b_l) ? 16'b0 : final_fixed_6b_l;
        end else begin
            out[31:16] = 16'b0;
            out[15:0]  = (is_zero_12b || is_nar_12b) ? 16'b0 : final_fixed_12b;
        end
    end

endmodule
