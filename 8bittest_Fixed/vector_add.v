// =============================================================================
// vector_add.v — Verilog
// Element-wise pipelined fixed-point addition unit
// Reuses the strassen_preprocess module for consistent 4-cycle pipeline latency
// =============================================================================
`include "fixed_pkg.vh"

module vector_add #(
    parameter SZJ        = 8,
    parameter DATA_WIDTH = `DATA_WIDTH,
    parameter FRAC_WIDTH = `FRAC_WIDTH
) (
    input  wire                             clk,
    input  wire                             resetn,
    input  wire [SZJ*DATA_WIDTH-1:0]        in_a,
    input  wire [SZJ*DATA_WIDTH-1:0]        in_b,
    output wire [SZJ*DATA_WIDTH-1:0]        out
);

    // Reuse the existing strassen_preprocess module which already implements
    // a pipelined saturating fixed-point adder with 4-cycle latency
    strassen_preprocess #(
        .WIDTH(SZJ),
        .DATA_WIDTH(DATA_WIDTH),
        .FRAC_WIDTH(FRAC_WIDTH)
    ) adder_inst (
        .clk(clk),
        .resetn(resetn),
        .op_sub(1'b0),        // Addition
        .passthrough(1'b0),   // Normal addition (not bypass)
        .in_a(in_a),
        .in_b(in_b),
        .out(out)
    );

endmodule
