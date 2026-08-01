// =============================================================================
// posit_add_simd.v — Verilog
// Reconfigurable SIMD Posit Adder Wrapper
// Switches between 3x 8-bit posit addition and 6x 4-bit posit additions
// =============================================================================
`include "posit_pkg.vh"

module posit_add_simd (
    input  wire         clk,
    input  wire         resetn,
    input  wire         simd_mode, // 0 = 3x 8-bit, 1 = 6x 4-bit SIMD
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

    // --- 6x 4-bit Adders ---
    wire [3:0] out_4b_0, out_4b_1, out_4b_2, out_4b_3, out_4b_4, out_4b_5;
    posit_add #(.POSIT_WIDTH(4), .POSIT_ES(1)) adder_4b_0 (
        .clk(clk), .resetn(resetn), .op_sub(op_sub),
        .in_a(in_a[3:0]), .in_b(in_b[3:0]), .out(out_4b_0)
    );
    posit_add #(.POSIT_WIDTH(4), .POSIT_ES(1)) adder_4b_1 (
        .clk(clk), .resetn(resetn), .op_sub(op_sub),
        .in_a(in_a[7:4]), .in_b(in_b[7:4]), .out(out_4b_1)
    );
    posit_add #(.POSIT_WIDTH(4), .POSIT_ES(1)) adder_4b_2 (
        .clk(clk), .resetn(resetn), .op_sub(op_sub),
        .in_a(in_a[11:8]), .in_b(in_b[11:8]), .out(out_4b_2)
    );
    posit_add #(.POSIT_WIDTH(4), .POSIT_ES(1)) adder_4b_3 (
        .clk(clk), .resetn(resetn), .op_sub(op_sub),
        .in_a(in_a[15:12]), .in_b(in_b[15:12]), .out(out_4b_3)
    );
    posit_add #(.POSIT_WIDTH(4), .POSIT_ES(1)) adder_4b_4 (
        .clk(clk), .resetn(resetn), .op_sub(op_sub),
        .in_a(in_a[19:16]), .in_b(in_b[19:16]), .out(out_4b_4)
    );
    posit_add #(.POSIT_WIDTH(4), .POSIT_ES(1)) adder_4b_5 (
        .clk(clk), .resetn(resetn), .op_sub(op_sub),
        .in_a(in_a[23:20]), .in_b(in_b[23:20]), .out(out_4b_5)
    );

    always @(*) begin
        if (simd_mode) begin
            out = {out_4b_5, out_4b_4, out_4b_3, out_4b_2, out_4b_1, out_4b_0};
        end else begin
            out = {out_8b_2, out_8b_1, out_8b_0};
        end
    end

endmodule
