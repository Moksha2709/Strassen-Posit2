// =============================================================================
// posit_decode.v — Verilog (converted from posit_decode.sv)
// Combinational Posit decoder: raw posit → {sign, is_zero, is_nar, scale, fraction}
// =============================================================================
`include "posit_pkg.vh"

module posit_decode #(
    parameter POSIT_WIDTH = `POSIT_WIDTH,
    parameter POSIT_ES    = `POSIT_ES,
    parameter DECODED_W   = 10 + POSIT_WIDTH
) (
    input  wire [POSIT_WIDTH-1:0] in,
    output reg  [DECODED_W-1:0]   out
);

    // Field position localparams
    localparam PD_SIGN     = DECODED_W - 1;
    localparam PD_IS_ZERO  = DECODED_W - 2;
    localparam PD_IS_NAR   = DECODED_W - 3;
    localparam PD_SCALE_HI = DECODED_W - 4;
    localparam PD_SCALE_LO = POSIT_WIDTH;
    localparam PD_FRAC_HI  = POSIT_WIDTH - 1;
    localparam PD_FRAC_LO  = 0;

    wire sign;
    wire is_zero;
    wire is_nar;
    wire [POSIT_WIDTH-1:0] in_abs;
    wire r_bit;
    wire [POSIT_WIDTH-2:0] body;

    reg  [4:0]            k;
    reg  signed [5:0]     regime_val;
    reg  [POSIT_WIDTH-2:0] body_shifted;
    reg  [ (POSIT_ES > 0 ? POSIT_ES-1 : 0) : 0 ] exponent;

    assign sign    = in[POSIT_WIDTH-1];
    assign is_zero = (in == {POSIT_WIDTH{1'b0}});
    assign is_nar  = (in == {1'b1, {(POSIT_WIDTH-1){1'b0}}});
    assign in_abs  = sign ? (-in) : in;
    assign r_bit   = in_abs[POSIT_WIDTH-2];
    assign body    = in_abs[POSIT_WIDTH-2:0];

    integer i_iter;
    always @(*) begin
        // --- Count regime run length ---
        k = 5'd0;
        for (i_iter = POSIT_WIDTH-2; i_iter >= 0; i_iter = i_iter - 1) begin
            if (in_abs[i_iter] == r_bit) begin
                if (k == (POSIT_WIDTH - 2 - i_iter)) begin
                    k = k + 1;
                end
            end
        end

        // --- Calculate regime value ---
        if (r_bit)
            regime_val = $signed({1'b0, k}) - 1;
        else
            regime_val = -$signed({1'b0, k});

        // --- Shift body to align exponent and fraction ---
        if (k == POSIT_WIDTH - 1)
            body_shifted = {(POSIT_WIDTH-1){1'b0}};
        else
            body_shifted = body << (k + 1);

        // --- Extract exponent ---
        if (POSIT_ES > 0)
            exponent = body_shifted[POSIT_WIDTH-2 -: (POSIT_ES > 0 ? POSIT_ES : 1)];
        else
            exponent = 1'b0;

        // --- Assemble decoded output ---
        out[PD_SIGN]    = sign;
        out[PD_IS_ZERO] = is_zero;
        out[PD_IS_NAR]  = is_nar;

        if (is_zero || is_nar) begin
            out[PD_SCALE_HI:PD_SCALE_LO] = 7'd0;
            out[PD_FRAC_HI:PD_FRAC_LO]   = {POSIT_WIDTH{1'b0}};
        end else begin
            out[PD_SCALE_HI:PD_SCALE_LO] = (regime_val * (1 << POSIT_ES))
                                            + $signed({1'b0, exponent});
            out[PD_FRAC_HI:PD_FRAC_LO]   = {1'b1,
                                             body_shifted[POSIT_WIDTH-2-POSIT_ES:0],
                                             {POSIT_ES{1'b0}}};
        end
    end

endmodule
