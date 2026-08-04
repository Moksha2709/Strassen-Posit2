// =============================================================================
// strassen_preprocess.v — Verilog
// Parallel fixed-point adders for sub-matrix add/sub preprocessing on-the-fly
// 4-cycle pipeline latency
// =============================================================================
`include "fixed_pkg.vh"
`include "strassen_pkg.vh"

module strassen_preprocess #(
    parameter WIDTH       = 8,
    parameter DATA_WIDTH  = `DATA_WIDTH,
    parameter FRAC_WIDTH  = `FRAC_WIDTH
) (
    input  wire                             clk,
    input  wire                             resetn,
    input  wire                             op_sub,      // 0=add, 1=sub
    input  wire                             passthrough, // 1=bypass (add with 0)

    // Stream data paths (flat vectors)
    input  wire [WIDTH*DATA_WIDTH-1:0]     in_a,
    input  wire [WIDTH*DATA_WIDTH-1:0]     in_b,
    output reg  [WIDTH*DATA_WIDTH-1:0]     out
);

    // 4 stages delay registers
    reg [WIDTH*DATA_WIDTH-1:0] r1, r2, r3, r4;

    genvar i;
    generate
        for (i = 0; i < WIDTH; i = i + 1) begin : adder_gen
            wire signed [DATA_WIDTH-1:0] a_val = in_a[i*DATA_WIDTH +: DATA_WIDTH];
            wire signed [DATA_WIDTH-1:0] b_val = passthrough ? {DATA_WIDTH{1'b0}} : in_b[i*DATA_WIDTH +: DATA_WIDTH];
            wire signed [DATA_WIDTH:0]   sum = op_sub ? (a_val - b_val) : (a_val + b_val);
            wire [DATA_WIDTH-1:0]        clipped_sum;

            assign clipped_sum = (sum > 2**(DATA_WIDTH-1) - 1) ? (2**(DATA_WIDTH-1) - 1) :
                                 (sum < -(2**(DATA_WIDTH-1)))   ? (-(2**(DATA_WIDTH-1)))   :
                                 sum[DATA_WIDTH-1:0];

            always @(posedge clk or negedge resetn) begin
                if (!resetn) begin
                    r1[i*DATA_WIDTH +: DATA_WIDTH] <= 0;
                    r2[i*DATA_WIDTH +: DATA_WIDTH] <= 0;
                    r3[i*DATA_WIDTH +: DATA_WIDTH] <= 0;
                    r4[i*DATA_WIDTH +: DATA_WIDTH] <= 0;
                end else begin
                    r1[i*DATA_WIDTH +: DATA_WIDTH] <= clipped_sum;
                    r2[i*DATA_WIDTH +: DATA_WIDTH] <= r1[i*DATA_WIDTH +: DATA_WIDTH];
                    r3[i*DATA_WIDTH +: DATA_WIDTH] <= r2[i*DATA_WIDTH +: DATA_WIDTH];
                    r4[i*DATA_WIDTH +: DATA_WIDTH] <= r3[i*DATA_WIDTH +: DATA_WIDTH];
                end
            end
        end
    endgenerate

    always @(*) begin
        out = r4;
    end

endmodule
