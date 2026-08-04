// =============================================================================
// fixed_to_posit_conv.v — Verilog
// Unified Dynamic Boundary Fixed-to-Posit Converter
// Converts Fixed-Point (16-bit or dual Q4.4) back to raw Posit (12-bit or dual 6-bit)
// =============================================================================
`include "posit_pkg.vh"

module fixed_to_posit_conv (
    input  wire [31:0] in,        // Fixed-point input
                                  // in[15:0] = 16-bit fixed-point (Q8.8)
    output reg  [11:0] out        // Raw output posit
                                  // 12-bit raw posit
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
    // 3. Output Multiplexer
    // =========================================================================
    always @(*) begin
        out = encoded_12b;
    end

endmodule
