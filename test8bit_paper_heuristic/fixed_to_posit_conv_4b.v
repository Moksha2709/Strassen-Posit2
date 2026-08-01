// =============================================================================
// fixed_to_posit_conv_4b.v — Verilog
// Encodes a 16-bit signed Q4.4 fixed-point value to a 4-bit Posit (POSIT(4,0))
// Uses symmetric midpoint thresholding and 2's complement negation.
// =============================================================================
`include "posit_pkg.vh"

module fixed_to_posit_conv_4b (
    input  wire signed [15:0] in,  // 16-bit Fixed-point (Q4.4)
    output reg         [3:0]  out  // 4-bit Posit
);

    wire signed [15:0] abs_val = (in[15] == 1'b1) ? (-in) : in;
    reg [3:0] abs_posit;

    always @(*) begin
        if (abs_val < 16'sd2)       abs_posit = 4'd0; // 0.0
        else if (abs_val < 16'sd6)  abs_posit = 4'd1; // 0.25 (midpoint = 2)
        else if (abs_val < 16'sd10) abs_posit = 4'd2; // 0.5  (midpoint = 6)
        else if (abs_val < 16'sd14) abs_posit = 4'd3; // 0.75 (midpoint = 10)
        else if (abs_val < 16'sd20) abs_posit = 4'd4; // 1.0  (midpoint = 14)
        else if (abs_val < 16'sd28) abs_posit = 4'd5; // 1.5  (midpoint = 20)
        else if (abs_val < 16'sd48) abs_posit = 4'd6; // 2.0  (midpoint = 28)
        else                        abs_posit = 4'd7; // 4.0  (midpoint = 48)

        if (in[15] == 1'b1) begin
            out = -abs_posit; // 2's complement negation holds exactly for Posits
        end else begin
            out = abs_posit;
        end
    end
endmodule
