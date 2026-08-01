// =============================================================================
// fixed_to_posit_conv.v — Verilog
// Unified Dynamic Boundary Fixed-to-Posit Converter
// Converts Fixed-Point (16-bit or dual Q4.4) back to raw Posit (12-bit or dual 6-bit)
// =============================================================================
`include "posit_pkg.vh"

module fixed_to_posit_conv (
    input  wire        simd_mode, // 0 = 12-bit mode, 1 = dual 6-bit SIMD mode
    input  wire [31:0] in,        // Fixed-point input
                                  // simd_mode=0: in[15:0] = 16-bit fixed-point (Q8.8)
                                  // simd_mode=1: in[31:16] = High Q4.4 (padded), in[15:0] = Low Q4.4 (padded)
    output reg  [11:0] out        // Raw output posit
                                  // simd_mode=0: 12-bit raw posit
                                  // simd_mode=1: [11:6] = High 6-bit posit, [5:0] = Low 6-bit posit
);

    // =========================================================================
    // 1. 12-bit Mode Processing Path (Q8.8 -> 12-bit Posit)
    // =========================================================================
    wire [15:0] fixed_12b = in[15:0];
    wire        sign_12b  = fixed_12b[15];
    wire [15:0] abs_12b   = sign_12b ? (-fixed_12b) : fixed_12b;
    wire        is_zero_12b = (fixed_12b == 16'b0);

    // Find leading one of absolute value
    reg [3:0] lead_one_12b;
    integer i12;
    always @(*) begin
        lead_one_12b = 4'd0;
        for (i12 = 0; i12 < 16; i12 = i12 + 1) begin
            if (abs_12b[i12] == 1'b1)
                lead_one_12b = i12[3:0];
        end
    end

    wire signed [6:0] scale_12b = $signed({3'b0, lead_one_12b}) - 7'sd8;
    wire [15:0] normalized_12b  = abs_12b << (4'd15 - lead_one_12b);

    // Assemble decoded struct for 12-bit
    wire [21:0] dec_12b;
    assign dec_12b[21]      = sign_12b;
    assign dec_12b[20]      = is_zero_12b;
    assign dec_12b[19]      = 1'b0; // is_nar
    assign dec_12b[18:12]   = scale_12b;
    assign dec_12b[11:0]    = normalized_12b[15:4]; // 12-bit fraction (including hidden 1)

    // Call encoder logic for 12-bit
    wire [11:0] encoded_12b;
    posit_encode #(.POSIT_WIDTH(12), .POSIT_ES(1)) enc_12b (
        .in(dec_12b),
        .out(encoded_12b)
    );

    // =========================================================================
    // 2. 6-bit Mode Processing Path (Dual Q4.4 -> Dual 6-bit Posit)
    // =========================================================================
    // High Path
    wire [7:0] fixed_6b_h  = in[23:16]; // Extract Q4.4 from padded 16-bit
    wire       sign_6b_h   = fixed_6b_h[7];
    wire [7:0] abs_6b_h    = sign_6b_h ? (-fixed_6b_h) : fixed_6b_h;
    wire       is_zero_6b_h = (fixed_6b_h == 8'b0);

    reg [2:0] lead_one_6b_h;
    integer i6h;
    always @(*) begin
        lead_one_6b_h = 3'd0;
        for (i6h = 0; i6h < 8; i6h = i6h + 1) begin
            if (abs_6b_h[i6h] == 1'b1)
                lead_one_6b_h = i6h[2:0];
        end
    end

    wire signed [6:0] scale_6b_h = $signed({4'b0, lead_one_6b_h}) - 7'sd4;
    wire [7:0] normalized_6b_h   = abs_6b_h << (3'd7 - lead_one_6b_h);

    wire [15:0] dec_6b_h;
    assign dec_6b_h[15]     = sign_6b_h;
    assign dec_6b_h[14]     = is_zero_6b_h;
    assign dec_6b_h[13]     = 1'b0; // is_nar
    assign dec_6b_h[12:6]   = scale_6b_h;
    assign dec_6b_h[5:0]    = normalized_6b_h[7:2]; // 6-bit fraction

    wire [5:0] encoded_6b_h;
    posit_encode #(.POSIT_WIDTH(6), .POSIT_ES(1)) enc_6b_h (
        .in(dec_6b_h),
        .out(encoded_6b_h)
    );

    // Low Path
    wire [7:0] fixed_6b_l  = in[7:0];
    wire       sign_6b_l   = fixed_6b_l[7];
    wire [7:0] abs_6b_l    = sign_6b_l ? (-fixed_6b_l) : fixed_6b_l;
    wire       is_zero_6b_l = (fixed_6b_l == 8'b0);

    reg [2:0] lead_one_6b_l;
    integer i6l;
    always @(*) begin
        lead_one_6b_l = 3'd0;
        for (i6l = 0; i6l < 8; i6l = i6l + 1) begin
            if (abs_6b_l[i6l] == 1'b1)
                lead_one_6b_l = i6l[2:0];
        end
    end

    wire signed [6:0] scale_6b_l = $signed({4'b0, lead_one_6b_l}) - 7'sd4;
    wire [7:0] normalized_6b_l   = abs_6b_l << (3'd7 - lead_one_6b_l);

    wire [15:0] dec_6b_l;
    assign dec_6b_l[15]     = sign_6b_l;
    assign dec_6b_l[14]     = is_zero_6b_l;
    assign dec_6b_l[13]     = 1'b0; // is_nar
    assign dec_6b_l[12:6]   = scale_6b_l;
    assign dec_6b_l[5:0]    = normalized_6b_l[7:2]; // 6-bit fraction

    wire [5:0] encoded_6b_l;
    posit_encode #(.POSIT_WIDTH(6), .POSIT_ES(1)) enc_6b_l (
        .in(dec_6b_l),
        .out(encoded_6b_l)
    );

    // =========================================================================
    // 3. Output Multiplexer
    // =========================================================================
    always @(*) begin
        if (simd_mode) begin
            out = {encoded_6b_h, encoded_6b_l};
        end else begin
            out = encoded_12b;
        end
    end

endmodule
