// =============================================================================
// posit_to_fixed_conv_8b_wide.v — Verilog
// Converts 8-bit Posit(8,1) to 24-bit Fixed-Point Q8.16 format
// =============================================================================
`include "posit_pkg.vh"

module posit_to_fixed_conv_8b_wide (
    input  wire [7:0]  in,  // 8-bit Posit
    output reg  [23:0] out  // 24-bit Fixed-point (Q8.16)
);

    wire [17:0] dec;
    posit_decode #(.POSIT_WIDTH(8), .POSIT_ES(1)) dec_inst (.in(in), .out(dec));

    wire sign = dec[17];
    wire is_zero = dec[16];
    wire signed [6:0] scale = dec[14:8];
    wire [7:0] frac = dec[7:0]; // 8-bit fraction with hidden 1 at frac[7]

    always @(*) begin
        if (is_zero) begin
            out = 24'b0;
        end else begin
            // Shift frac to align to Q8.16 format
            // Radix point is at bit 16, so frac[7] (representing 2^0) should map to bit 16
            // This requires shifting frac left by 9 bits when scale = 0
            if (scale >= -9)
                out = (frac << (scale + 9));
            else
                out = (frac >> (-9 - scale));
            
            if (sign) out = -out;
        end
    end

endmodule
