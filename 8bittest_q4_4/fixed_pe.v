// =============================================================================
// fixed_pe.v — Verilog
// Single Processing Element: Q8.8 multiplier + saturating accumulator
// 4-cycle multiplication pipeline latency
// =============================================================================
`include "fixed_pkg.vh"

module fixed_pe #(
    parameter DATA_WIDTH = `DATA_WIDTH,
    parameter FRAC_WIDTH = `FRAC_WIDTH
) (
    input  wire                         clk,
    input  wire                         resetn,

    // Control signals
    input  wire                         load_weight,
    input  wire                         clear_quire,
    input  wire                         shift_out,
    input  wire                         shift_load,

    // Data paths
    input  wire [DATA_WIDTH-1:0]        posit_in_a,    // Activation (from west)
    input  wire [DATA_WIDTH-1:0]        posit_in_b,    // Weight / Shift-in (from north)

    output wire [DATA_WIDTH-1:0]        posit_out_a,   // Activation (to east)
    output wire [DATA_WIDTH-1:0]        posit_out_b    // Weight / Shift-out (to south)
);

    // Registers
    reg  [DATA_WIDTH-1:0] weight_reg;
    reg  [DATA_WIDTH-1:0] act_reg;
    reg  [DATA_WIDTH-1:0] readout_reg;
    reg  [DATA_WIDTH-1:0] accum_reg;

    // --- Pipelined Signed Fixed-Point Multiplier (4 stages) ---
    // Delay stage registers to model 4-cycle latency
    reg signed [2*DATA_WIDTH-1:0] prod_r1;
    reg signed [2*DATA_WIDTH-1:0] prod_r2;
    reg signed [2*DATA_WIDTH-1:0] prod_r3;
    reg signed [DATA_WIDTH-1:0]   mult_out;

    wire signed [DATA_WIDTH-1:0] a_signed = act_reg;
    wire signed [DATA_WIDTH-1:0] b_signed = weight_reg;

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            prod_r1  <= 0;
            prod_r2  <= 0;
            prod_r3  <= 0;
            mult_out <= 0;
        end else begin
            prod_r1  <= a_signed * b_signed;
            prod_r2  <= prod_r1;
            prod_r3  <= prod_r2;
            
            // Shift and Clip (Stage 4)
            mult_out <= clip_fixed(prod_r3 >>> FRAC_WIDTH);
        end
    end

    function [DATA_WIDTH-1:0] clip_fixed;
        input signed [2*DATA_WIDTH-1:0] val;
        begin
            if (val > 2**(DATA_WIDTH-1) - 1)
                clip_fixed = 2**(DATA_WIDTH-1) - 1;
            else if (val < -(2**(DATA_WIDTH-1)))
                clip_fixed = -(2**(DATA_WIDTH-1));
            else
                clip_fixed = val[DATA_WIDTH-1:0];
        end
    endfunction

    // --- Combinational Adder with Saturation ---
    wire signed [DATA_WIDTH-1:0] sum_in_a = accum_reg;
    wire signed [DATA_WIDTH-1:0] sum_in_b = mult_out;
    wire signed [DATA_WIDTH:0]   sum = sum_in_a + sum_in_b;
    wire [DATA_WIDTH-1:0]        adder_out;

    assign adder_out = (sum > 2**(DATA_WIDTH-1) - 1) ? (2**(DATA_WIDTH-1) - 1) :
                       (sum < -(2**(DATA_WIDTH-1)))   ? (-(2**(DATA_WIDTH-1)))   :
                       sum[DATA_WIDTH-1:0];

    // --- Accumulator Register Update ---
    always @(posedge clk or negedge resetn) begin
        if (!resetn)
            accum_reg <= {DATA_WIDTH{1'b0}};
        else if (clear_quire)
            accum_reg <= {DATA_WIDTH{1'b0}};
        else
            accum_reg <= adder_out;
    end

    // --- Pipeline activation flow to the east ---
    always @(posedge clk or negedge resetn) begin
        if (!resetn)
            act_reg <= {DATA_WIDTH{1'b0}};
        else
            act_reg <= posit_in_a;
    end
    assign posit_out_a = act_reg;

    // --- Weight loading and shift-out registers ---
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            weight_reg  <= {DATA_WIDTH{1'b0}};
            readout_reg <= {DATA_WIDTH{1'b0}};
        end else begin
            if (load_weight)
                weight_reg <= posit_in_b;

            if (shift_load)
                readout_reg <= accum_reg;
            else if (shift_out)
                readout_reg <= posit_in_b;
        end
    end

    // Output to the south
    assign posit_out_b = shift_out ? readout_reg : weight_reg;

endmodule
