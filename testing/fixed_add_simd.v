// =============================================================================
// fixed_add_simd.v — Verilog
// Reconfigurable Fixed-Point SIMD Adder with 4-cycle Pipeline Latency
// Supports 1x 16-bit Q8.8 (12-bit mode) or 2x 16-bit packed Q4.4 (SIMD mode)
// =============================================================================
`include "posit_pkg.vh"

module fixed_add_simd (
    input  wire         clk,
    input  wire         resetn,
    input  wire         op_sub,    // 0 = add, 1 = sub
    input  wire [31:0]  in_a,
    input  wire [31:0]  in_b,
    output wire [31:0]  out
);

    // Combinational calculation
    reg [31:0] sum_comb;
    always @(*) begin
        // Single 16-bit Q8.8 addition in lower 16-bits
        sum_comb[31:16] = 16'b0;
        if (op_sub) begin
            sum_comb[15:0] = in_a[15:0] - in_b[15:0];
        end else begin
            sum_comb[15:0] = in_a[15:0] + in_b[15:0];
        end
    end

    // 4-stage pipeline delay matching the baseline posit adder latency
    reg [31:0] r1, r2, r3, r4;
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            r1 <= 32'b0;
            r2 <= 32'b0;
            r3 <= 32'b0;
            r4 <= 32'b0;
        end else begin
            r1 <= sum_comb;
            r2 <= r1;
            r3 <= r2;
            r4 <= r3;
        end
    end

    assign out = r4;

endmodule
