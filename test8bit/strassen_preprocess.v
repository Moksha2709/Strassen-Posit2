// =============================================================================
// strassen_preprocess.v — Verilog
// Parallel 3-Channel 24-bit Fixed-Point Adders for Pre/Postprocessing (Q8.16)
// 4-cycle pipeline latency (Wide 72-bit bus width)
// =============================================================================
`include "posit_pkg.vh"
`include "strassen_pkg.vh"

module strassen_preprocess #(
    parameter WIDTH = 8,
    parameter DATA_WIDTH = 72
) (
    input  wire                             clk,
    input  wire                             resetn,
    input  wire                             op_sub,      // 0=add, 1=sub
    input  wire                             passthrough, // 1=bypass (add with 0)

    // Stream data paths (flat: carrying 3 packed 24-bit fixed elements per index = 72 bits)
    input  wire [WIDTH*DATA_WIDTH-1:0]      in_a,
    input  wire [WIDTH*DATA_WIDTH-1:0]      in_b,
    output wire [WIDTH*DATA_WIDTH-1:0]      out
);

    localparam ELEM_W = DATA_WIDTH / 3;

    genvar gj, ch;
    generate
        for (gj = 0; gj < WIDTH; gj = gj + 1) begin : element_loop
            for (ch = 0; ch < 3; ch = ch + 1) begin : channel_loop
                wire [ELEM_W-1:0] a_val = in_a[(gj*DATA_WIDTH + ch*ELEM_W) +: ELEM_W];
                wire [ELEM_W-1:0] b_val = passthrough ? {ELEM_W{1'b0}} : in_b[(gj*DATA_WIDTH + ch*ELEM_W) +: ELEM_W];
                
                fixed_add_4stage #(.BIT_W(ELEM_W)) adder_inst (
                    .clk(clk),
                    .resetn(resetn),
                    .op_sub(op_sub && !passthrough),
                    .in_a(a_val),
                    .in_b(b_val),
                    .out(out[(gj*DATA_WIDTH + ch*ELEM_W) +: ELEM_W])
                );
            end
        end
    endgenerate

endmodule

// Helper Module: 4-stage pipelined fixed-point adder
module fixed_add_4stage #(
    parameter BIT_W = 24
) (
    input  wire             clk,
    input  wire             resetn,
    input  wire             op_sub,
    input  wire [BIT_W-1:0] in_a,
    input  wire [BIT_W-1:0] in_b,
    output wire [BIT_W-1:0] out
);
    reg [BIT_W-1:0] sum_comb;
    always @(*) begin
        if (op_sub)
            sum_comb = in_a - in_b;
        else
            sum_comb = in_a + in_b;
    end

    reg [BIT_W-1:0] r1, r2, r3, r4;
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            r1 <= {BIT_W{1'b0}};
            r2 <= {BIT_W{1'b0}};
            r3 <= {BIT_W{1'b0}};
            r4 <= {BIT_W{1'b0}};
        end else begin
            r1 <= sum_comb;
            r2 <= r1;
            r3 <= r2;
            r4 <= r3;
        end
    end
    assign out = r4;
endmodule
