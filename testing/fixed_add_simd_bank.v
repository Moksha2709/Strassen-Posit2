// =============================================================================
// fixed_add_simd_bank.v — Verilog
// Parameterized bank of reconfigurable SIMD fixed-point adders
// =============================================================================
`include "posit_pkg.vh"

module fixed_add_simd_bank #(
    parameter WIDTH = 8
) (
    input  wire                 clk,
    input  wire                 resetn,
    input  wire                 op_sub,
    input  wire                 passthrough,
    input  wire [WIDTH*32-1:0]  in_a,
    input  wire [WIDTH*32-1:0]  in_b,
    output wire [WIDTH*32-1:0]  out
);

    genvar i;
    generate
        for (i = 0; i < WIDTH; i = i + 1) begin : adder_gen
            wire [31:0] a_val = in_a[i*32 +: 32];
            wire [31:0] b_val = passthrough ? 32'b0 : in_b[i*32 +: 32];
            
            fixed_add_simd adder_inst (
                .clk(clk),
                .resetn(resetn),
                .op_sub(op_sub),
                .in_a(a_val),
                .in_b(b_val),
                .out(out[i*32 +: 32])
            );
        end
    endgenerate

endmodule
