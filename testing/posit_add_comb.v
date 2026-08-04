// =============================================================================
// posit_add_comb.v — Verilog
// Combinational Posit adder/subtractor (no pipeline latency)
// =============================================================================
`include "posit_pkg.vh"

module posit_add_comb #(
    parameter DEFAULT_IS_SUB = 0,
    parameter POSIT_WIDTH    = `POSIT_WIDTH,
    parameter POSIT_ES       = `POSIT_ES,
    parameter DECODED_W      = 10 + POSIT_WIDTH
) (
    input  wire                         op_sub,
    input  wire [POSIT_WIDTH-1:0]       in_a,
    input  wire [POSIT_WIDTH-1:0]       in_b,
    output wire [POSIT_WIDTH-1:0]       out
);

    // Field position localparams
    localparam PD_SIGN     = DECODED_W - 1;
    localparam PD_IS_ZERO  = DECODED_W - 2;
    localparam PD_IS_NAR   = DECODED_W - 3;
    localparam PD_SCALE_HI = DECODED_W - 4;
    localparam PD_SCALE_LO = POSIT_WIDTH;
    localparam PD_FRAC_HI  = POSIT_WIDTH - 1;
    localparam PD_FRAC_LO  = 0;

    // --- Decoders ---
    wire [DECODED_W-1:0] dec_a;
    wire [DECODED_W-1:0] dec_b;

    posit_decode #(.POSIT_WIDTH(POSIT_WIDTH), .POSIT_ES(POSIT_ES))
        decode_inst_a (.in(in_a), .out(dec_a));
    posit_decode #(.POSIT_WIDTH(POSIT_WIDTH), .POSIT_ES(POSIT_ES))
        decode_inst_b (.in(in_b), .out(dec_b));

    // Stage 1 signals (combinational assignments)
    wire dec_a_sign_r1 = dec_a[PD_SIGN];
    wire dec_b_sign_r1 = dec_b[PD_SIGN] ^ op_sub;
    wire signed [6:0] scale_a_r1 = $signed(dec_a[PD_SCALE_HI:PD_SCALE_LO]);
    wire signed [6:0] scale_b_r1 = $signed(dec_b[PD_SCALE_HI:PD_SCALE_LO]);
    wire [POSIT_WIDTH-1:0] frac_a_r1 = dec_a[PD_FRAC_HI:PD_FRAC_LO];
    wire [POSIT_WIDTH-1:0] frac_b_r1 = dec_b[PD_FRAC_HI:PD_FRAC_LO];
    wire is_zero_a_r1 = dec_a[PD_IS_ZERO];
    wire is_zero_b_r1 = dec_b[PD_IS_ZERO];
    wire is_nar_a_r1 = dec_a[PD_IS_NAR];
    wire is_nar_b_r1 = dec_b[PD_IS_NAR];

    // Stage 2 signals
    reg                          sign_stg2;
    reg  signed [6:0]            scale_stg2;
    reg                          opp_sign_stg2;
    reg                          a_gt_b;
    reg  signed [6:0]            scale_diff;
    reg  [5:0]                   shift_amt;
    reg  [POSIT_WIDTH-1:0]       frac_large;
    reg  [POSIT_WIDTH-1:0]       frac_small;
    reg  [2*POSIT_WIDTH-1:0]     frac_small_shifted;

    always @(*) begin
        scale_diff = scale_a_r1 - scale_b_r1;
        a_gt_b = (scale_diff > 0) || (scale_diff == 0 && frac_a_r1 > frac_b_r1);

        if (is_zero_a_r1) begin
            sign_stg2     = dec_b_sign_r1;
            scale_stg2    = scale_b_r1;
            frac_large    = frac_b_r1;
            frac_small    = {POSIT_WIDTH{1'b0}};
            shift_amt     = 6'd0;
            opp_sign_stg2 = 1'b0;
        end else if (is_zero_b_r1) begin
            sign_stg2     = dec_a_sign_r1;
            scale_stg2    = scale_a_r1;
            frac_large    = frac_a_r1;
            frac_small    = {POSIT_WIDTH{1'b0}};
            shift_amt     = 6'd0;
            opp_sign_stg2 = 1'b0;
        end else if (a_gt_b) begin
            sign_stg2     = dec_a_sign_r1;
            scale_stg2    = scale_a_r1;
            frac_large    = frac_a_r1;
            frac_small    = frac_b_r1;
            shift_amt     = scale_diff[5:0];
            opp_sign_stg2 = dec_a_sign_r1 ^ dec_b_sign_r1;
        end else begin
            sign_stg2     = dec_b_sign_r1;
            scale_stg2    = scale_b_r1;
            frac_large    = frac_b_r1;
            frac_small    = frac_a_r1;
            shift_amt     = (-scale_diff[5:0]);
            opp_sign_stg2 = dec_a_sign_r1 ^ dec_b_sign_r1;
        end

        if (shift_amt >= 2*POSIT_WIDTH)
            frac_small_shifted = {(2*POSIT_WIDTH){1'b0}};
        else
            frac_small_shifted = {frac_small, {POSIT_WIDTH{1'b0}}} >> shift_amt;
    end

    wire sign_r2 = sign_stg2;
    wire signed [6:0] scale_r2 = scale_stg2;
    wire opp_sign_r2 = opp_sign_stg2;
    wire [POSIT_WIDTH-1:0] frac_large_r2 = frac_large;
    wire [2*POSIT_WIDTH-1:0] frac_small_shifted_r2 = frac_small_shifted;
    wire is_zero_r2 = is_zero_a_r1 && is_zero_b_r1;
    wire is_nar_r2 = is_nar_a_r1 || is_nar_b_r1;

    // Stage 3 signals
    reg  [2*POSIT_WIDTH:0]       frac_sum;
    reg  [5:0]                   lz_count;
    reg  [2*POSIT_WIDTH:0]       frac_sum_norm;
    reg  signed [6:0]            scale_adj;

    integer lz_iter;
    always @(*) begin
        if (opp_sign_r2)
            frac_sum = {1'b0, frac_large_r2, {POSIT_WIDTH{1'b0}}} - {1'b0, frac_small_shifted_r2};
        else
            frac_sum = {1'b0, frac_large_r2, {POSIT_WIDTH{1'b0}}} + {1'b0, frac_small_shifted_r2};

        lz_count = 6'd0;
        if (frac_sum[2*POSIT_WIDTH]) begin
            scale_adj     = scale_r2 + 1;
            frac_sum_norm = frac_sum >> 1;
        end else begin
            for (lz_iter = 2*POSIT_WIDTH-1; lz_iter >= 0; lz_iter = lz_iter - 1) begin
                if (frac_sum[lz_iter] == 1'b1) begin
                    // Leading 1 found
                end else begin
                    if (lz_count == (2*POSIT_WIDTH - 1 - lz_iter))
                        lz_count = lz_count + 1;
                end
            end
            scale_adj     = scale_r2 - $signed({1'b0, lz_count});
            frac_sum_norm = frac_sum << lz_count;
        end
    end

    wire sign_r3 = sign_r2;
    wire signed [6:0] scale_r3 = scale_adj;
    wire [POSIT_WIDTH-1:0] frac_r3 = frac_sum_norm[2*POSIT_WIDTH-1 : POSIT_WIDTH];
    wire is_zero_r3 = is_zero_r2 || (frac_sum == {(2*POSIT_WIDTH+1){1'b0}});
    wire is_nar_r3 = is_nar_r2;

    // Stage 4 — Encoder
    wire [DECODED_W-1:0] dec_to_encode;
    assign dec_to_encode[PD_SIGN]                 = sign_r3;
    assign dec_to_encode[PD_IS_ZERO]              = is_zero_r3;
    assign dec_to_encode[PD_IS_NAR]               = is_nar_r3;
    assign dec_to_encode[PD_SCALE_HI:PD_SCALE_LO] = scale_r3;
    assign dec_to_encode[PD_FRAC_HI:PD_FRAC_LO]   = frac_r3;

    posit_encode #(.POSIT_WIDTH(POSIT_WIDTH), .POSIT_ES(POSIT_ES))
        encoder_inst (.in(dec_to_encode), .out(out));

endmodule
