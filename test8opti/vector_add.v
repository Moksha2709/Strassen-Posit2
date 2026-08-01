// =============================================================================
// vector_add.v — Verilog
// Element-wise pipelined Posit addition unit
// =============================================================================
`include "posit_pkg.vh"

module vector_add #(
    parameter SZJ         = `DEFAULT_SZJ,
    parameter POSIT_WIDTH = `POSIT_WIDTH,
    parameter POSIT_ES    = `POSIT_ES
) (
    input  wire                             clk,
    input  wire                             resetn,
    input  wire                             simd_mode,
    input  wire [SZJ*POSIT_WIDTH-1:0]       in_a,
    input  wire [SZJ*POSIT_WIDTH-1:0]       in_b,
    output wire [SZJ*POSIT_WIDTH-1:0]       out
);

    genvar i;
    generate
        for (i = 0; i < SZJ; i = i + 1) begin : gen_adders
            posit_add_simd adder_inst (
                .clk(clk),
                .resetn(resetn),
                .simd_mode(simd_mode),
                .op_sub(1'b0), // Addition
                .in_a(in_a[i*POSIT_WIDTH +: POSIT_WIDTH]),
                .in_b(in_b[i*POSIT_WIDTH +: POSIT_WIDTH]),
                .out(out[i*POSIT_WIDTH +: POSIT_WIDTH])
            );
        end
    endgenerate

endmodule
