// =============================================================================
// posit_encode.v — Verilog (converted from posit_encode.sv)
// Combinational Posit encoder: {sign, is_zero, is_nar, scale, fraction} → raw posit
// =============================================================================
`include "posit_pkg.vh"

module posit_encode #(
    parameter POSIT_WIDTH = `POSIT_WIDTH,
    parameter POSIT_ES    = `POSIT_ES,
    parameter DECODED_W   = 10 + POSIT_WIDTH
) (
    input  wire [DECODED_W-1:0]   in,
    output reg  [POSIT_WIDTH-1:0] out
);

    // Field position localparams
    localparam PD_SIGN     = DECODED_W - 1;
    localparam PD_IS_ZERO  = DECODED_W - 2;
    localparam PD_IS_NAR   = DECODED_W - 3;
    localparam PD_SCALE_HI = DECODED_W - 4;
    localparam PD_SCALE_LO = POSIT_WIDTH;
    localparam PD_FRAC_HI  = POSIT_WIDTH - 1;
    localparam PD_FRAC_LO  = 0;

    // Extract input fields
    wire              in_sign;
    wire              in_is_zero;
    wire              in_is_nar;
    wire [6:0]        in_scale_raw;
    wire [POSIT_WIDTH-1:0] in_frac;

    assign in_sign      = in[PD_SIGN];
    assign in_is_zero   = in[PD_IS_ZERO];
    assign in_is_nar    = in[PD_IS_NAR];
    assign in_scale_raw = in[PD_SCALE_HI:PD_SCALE_LO];
    assign in_frac      = in[PD_FRAC_HI:PD_FRAC_LO];

    // Internal registers for combinational logic
    reg signed [6:0]  scale;
    reg signed [5:0]  regime_val;
    reg [ (POSIT_ES > 0 ? POSIT_ES-1 : 0) : 0 ] exponent;
    reg [4:0]         k;
    reg               r_bit;
    reg [POSIT_WIDTH-2:0] slice;
    reg [3*POSIT_WIDTH+POSIT_ES-1:0] raw_body;
    reg [3*POSIT_WIDTH+POSIT_ES-1:0] aligned_body;

    reg               lsb;
    reg               guard;
    reg               round_bit;
    reg               sticky;
    reg               round_up;
    reg [POSIT_WIDTH-1:0] unrounded_posit;
    reg [POSIT_WIDTH-1:0] abs_posit;

    always @(*) begin
        if (in_is_nar) begin
            out = {1'b1, {(POSIT_WIDTH-1){1'b0}}};
        end else if (in_is_zero) begin
            out = {POSIT_WIDTH{1'b0}};
        end else begin
            // Flooring division for signed scale
            scale      = $signed(in_scale_raw);
            regime_val = scale >>> POSIT_ES;
            exponent   = scale - (regime_val * (1 << POSIT_ES));

            // Determine regime run length and bit
            if (regime_val >= 0) begin
                r_bit = 1'b1;
                k = (regime_val >= POSIT_WIDTH - 1)
                    ? (POSIT_WIDTH - 1)
                    : (regime_val[4:0] + 5'd1);
            end else begin
                r_bit = 1'b0;
                k = (-regime_val >= POSIT_WIDTH - 1)
                    ? (POSIT_WIDTH - 1)
                    : (-regime_val[4:0]);
            end

            // Construct unrounded body (exponent field is omitted if POSIT_ES == 0)
            if (POSIT_ES > 0) begin
                raw_body = { {POSIT_WIDTH{r_bit}},
                             ~r_bit,
                             exponent,
                             in_frac[POSIT_WIDTH-2:0],
                             {POSIT_WIDTH{1'b0}} };
            end else begin
                raw_body = { {POSIT_WIDTH{r_bit}},
                             ~r_bit,
                             in_frac[POSIT_WIDTH-2:0],
                             {POSIT_WIDTH{1'b0}} };
            end
            aligned_body = raw_body >> k;

            // Extract slice and rounding bits
            slice = aligned_body[2*POSIT_WIDTH + POSIT_ES - 1 : POSIT_WIDTH + POSIT_ES + 1];

            lsb       = aligned_body[POSIT_WIDTH + POSIT_ES + 1];
            guard     = aligned_body[POSIT_WIDTH + POSIT_ES];
            round_bit = aligned_body[POSIT_WIDTH + POSIT_ES - 1];
            sticky    = |aligned_body[POSIT_WIDTH + POSIT_ES - 2 : 0];

            round_up  = guard && (round_bit || sticky || lsb);

            unrounded_posit = {1'b0, slice};
            abs_posit       = unrounded_posit + {{(POSIT_WIDTH-1){1'b0}}, round_up};

            out = in_sign ? (-abs_posit) : abs_posit;
        end
    end

endmodule
