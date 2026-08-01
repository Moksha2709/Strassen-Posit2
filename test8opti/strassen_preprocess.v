// =============================================================================
// strassen_preprocess.v — Verilog
// Parallel 3-Channel 16-bit Fixed-Point Adders for Pre/Postprocessing
// 4-cycle pipeline latency (Optimized 48-bit bus width)
// =============================================================================
`include "posit_pkg.vh"
`include "strassen_pkg.vh"

module strassen_preprocess #(
    parameter WIDTH = 8,
    parameter DATA_WIDTH = 48
) (
    input  wire                             clk,
    input  wire                             resetn,
    input  wire                             op_sub,      // 0=add, 1=sub
    input  wire                             passthrough, // 1=bypass (add with 0)

    // Stream data paths (flat: carrying 3 packed 16-bit fixed elements per index = 48 bits)
    input  wire [WIDTH*DATA_WIDTH-1:0]      in_a,
    input  wire [WIDTH*DATA_WIDTH-1:0]      in_b,
    output wire [WIDTH*DATA_WIDTH-1:0]      out
);

    genvar gj, ch;
    generate
        for (gj = 0; gj < WIDTH; gj = gj + 1) begin : element_loop
            for (ch = 0; ch < 3; ch = ch + 1) begin : channel_loop
                wire [15:0] a_val = in_a[(gj*48 + ch*16) +: 16];
                wire [15:0] b_val = passthrough ? 16'b0 : in_b[(gj*48 + ch*16) +: 16];
                
                fixed_add_4stage adder_inst (
                    .clk(clk),
                    .resetn(resetn),
                    .op_sub(op_sub && !passthrough),
                    .in_a(a_val),
                    .in_b(b_val),
                    .out(out[(gj*48 + ch*16) +: 16])
                );
            end
        end
    endgenerate

endmodule

// Helper Module: 4-stage pipelined fixed-point adder
module fixed_add_4stage (
    input  wire        clk,
    input  wire        resetn,
    input  wire        op_sub,
    input  wire [15:0] in_a,
    input  wire [15:0] in_b,
    output wire [15:0] out
);
    reg [15:0] sum_comb;
    always @(*) begin
        if (op_sub)
            sum_comb = in_a - in_b;
        else
            sum_comb = in_a + in_b;
    end

    reg [15:0] r1, r2, r3, r4;
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            r1 <= 16'b0;
            r2 <= 16'b0;
            r3 <= 16'b0;
            r4 <= 16'b0;
        end else begin
            r1 <= sum_comb;
            r2 <= r1;
            r3 <= r2;
            r4 <= r3;
        end
    end
    assign out = r4;
endmodule
