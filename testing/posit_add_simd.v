// =============================================================================
// posit_add_simd.v — Verilog
// Reconfigurable SIMD Posit Adder Wrapper
// Switches between 3x 8-bit posit addition and 6x 4-bit posit additions
// =============================================================================
`include "posit_pkg.vh"

module posit_add_simd (
    input  wire         clk,
    input  wire         resetn,
    input  wire         op_sub,
    input  wire [23:0]  in_a,
    input  wire [23:0]  in_b,
    output reg  [23:0]  out
);

    // --- 3x 8-bit Adders ---
    wire [7:0] out_8b_0, out_8b_1, out_8b_2;
    posit_add #(.POSIT_WIDTH(8), .POSIT_ES(1)) adder_8b_0 (
        .clk(clk), .resetn(resetn), .op_sub(op_sub),
        .in_a(in_a[7:0]), .in_b(in_b[7:0]), .out(out_8b_0)
    );
    posit_add #(.POSIT_WIDTH(8), .POSIT_ES(1)) adder_8b_1 (
        .clk(clk), .resetn(resetn), .op_sub(op_sub),
        .in_a(in_a[15:8]), .in_b(in_b[15:8]), .out(out_8b_1)
    );
    posit_add #(.POSIT_WIDTH(8), .POSIT_ES(1)) adder_8b_2 (
        .clk(clk), .resetn(resetn), .op_sub(op_sub),
        .in_a(in_a[23:16]), .in_b(in_b[23:16]), .out(out_8b_2)
    );

    always @(*) begin
        out = {out_8b_2, out_8b_1, out_8b_0};
    end

endmodule
