// =============================================================================
// quire_acc.v — Verilog (converted from quire_acc.sv)
// 256-bit Quire accumulator with round-out to Posit
// =============================================================================
`include "posit_pkg.vh"

module quire_acc #(
    parameter POSIT_WIDTH       = `POSIT_WIDTH,
    parameter POSIT_ES          = `POSIT_ES,
    parameter QUIRE_WIDTH       = `QUIRE_WIDTH,
    parameter QUIRE_RADIX_POINT = `QUIRE_RADIX_POINT,
    parameter DECODED_W         = 10 + POSIT_WIDTH
) (
    input  wire                         clk,
    input  wire                         resetn,
    input  wire                         clear,
    input  wire                         sign,
    input  wire signed [6:0]            scale,
    input  wire [2*POSIT_WIDTH-1:0]     frac_double,
    input  wire                         is_zero,
    input  wire                         is_nar,
    output wire [POSIT_WIDTH-1:0]       round_out
);

    reg  [QUIRE_WIDTH-1:0] quire_reg;
    reg                    quire_nar;

    // --- Align fraction to Quire scale ---
    reg  [QUIRE_WIDTH-1:0] unshifted_frac;
    reg  [QUIRE_WIDTH-1:0] shifted_frac;
    reg  [QUIRE_WIDTH-1:0] val_to_add;

    always @(*) begin
        unshifted_frac = {
            {(QUIRE_WIDTH - 1 - QUIRE_RADIX_POINT){1'b0}},
            frac_double[2*POSIT_WIDTH-2 : 0],
            {(QUIRE_RADIX_POINT - 2*POSIT_WIDTH + 2){1'b0}}
        };

        if (scale >= 0) begin
            if (scale >= QUIRE_WIDTH)
                shifted_frac = {QUIRE_WIDTH{1'b0}};
            else
                shifted_frac = unshifted_frac << scale;
        end else begin
            if (-scale >= QUIRE_WIDTH)
                shifted_frac = {QUIRE_WIDTH{1'b0}};
            else
                shifted_frac = unshifted_frac >> (-scale);
        end

        if (is_zero)
            val_to_add = {QUIRE_WIDTH{1'b0}};
        else
            val_to_add = sign ? (-shifted_frac) : shifted_frac;
    end

    // --- Accumulator register ---
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            quire_reg <= {QUIRE_WIDTH{1'b0}};
            quire_nar <= 1'b0;
        end else if (clear) begin
            quire_reg <= {QUIRE_WIDTH{1'b0}};
            quire_nar <= 1'b0;
        end else begin
            if (is_nar)
                quire_nar <= 1'b1;
            quire_reg <= quire_reg + val_to_add;
        end
    end

    // --- Round Out logic (Quire → Posit) ---
    wire              q_sign;
    wire [QUIRE_WIDTH-1:0] q_abs;
    reg  [7:0]        leading_one_idx;
    wire signed [7:0] q_scale;
    wire [QUIRE_WIDTH-1:0] q_abs_shifted;
    wire [POSIT_WIDTH-1:0] q_frac;

    assign q_sign = quire_reg[QUIRE_WIDTH-1];
    assign q_abs  = q_sign ? (-quire_reg) : quire_reg;

    // Find index of leading 1
    integer qi;
    always @(*) begin
        leading_one_idx = 8'd0;
        for (qi = 0; qi < QUIRE_WIDTH; qi = qi + 1) begin
            if (q_abs[qi] == 1'b1)
                leading_one_idx = qi[7:0];
        end
    end

    assign q_scale      = $signed({1'b0, leading_one_idx}) - QUIRE_RADIX_POINT;
    assign q_abs_shifted = q_abs << (QUIRE_WIDTH - 1 - leading_one_idx);
    assign q_frac       = q_abs_shifted[QUIRE_WIDTH-1 : QUIRE_WIDTH - POSIT_WIDTH];

    // Assemble decoded struct for encoder
    localparam PD_SIGN     = DECODED_W - 1;
    localparam PD_IS_ZERO  = DECODED_W - 2;
    localparam PD_IS_NAR   = DECODED_W - 3;
    localparam PD_SCALE_HI = DECODED_W - 4;
    localparam PD_SCALE_LO = POSIT_WIDTH;
    localparam PD_FRAC_HI  = POSIT_WIDTH - 1;
    localparam PD_FRAC_LO  = 0;

    wire [DECODED_W-1:0] dec_out;
    assign dec_out[PD_SIGN]                 = q_sign;
    assign dec_out[PD_IS_ZERO]              = (quire_reg == {QUIRE_WIDTH{1'b0}});
    assign dec_out[PD_IS_NAR]               = quire_nar;
    assign dec_out[PD_SCALE_HI:PD_SCALE_LO] = q_scale[6:0];
    assign dec_out[PD_FRAC_HI:PD_FRAC_LO]   = q_frac;

    posit_encode #(.POSIT_WIDTH(POSIT_WIDTH), .POSIT_ES(POSIT_ES))
        encoder_inst (.in(dec_out), .out(round_out));

endmodule
