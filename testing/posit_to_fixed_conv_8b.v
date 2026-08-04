// =============================================================================
// posit_to_fixed_conv_8b.v — Verilog
// Converts 8-bit Posit(8,1) to 16-bit Fixed-Point Q4.4 format
// =============================================================================
`include "posit_pkg.vh"

module posit_to_fixed_conv_8b (
    input  wire [7:0]  in,  // 8-bit Posit
    output reg  [15:0] out  // 16-bit Fixed-point (Q4.4)
);

    wire [17:0] dec;
    posit_decode #(.POSIT_WIDTH(8), .POSIT_ES(1)) dec_inst (.in(in), .out(dec));

    wire sign = dec[17];
    wire is_zero = dec[16];
    wire signed [6:0] scale = dec[14:8];
    wire [7:0] frac = dec[7:0]; // 8-bit fraction with hidden 1 at frac[7]

    always @(*) begin
        if (is_zero) begin
            out = 16'b0;
        end else begin
            // Shift frac to align to Q4.4 format (hidden 1 shifted by scale - 3)
            if (scale >= 3)
                out = (frac << (scale - 3));
            else
                out = (frac >> (3 - scale));
            
            if (sign) out = -out;
        end
    end

endmodule
