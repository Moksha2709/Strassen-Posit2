// =============================================================================
// posit_mult.v — Verilog (converted from posit_mult.sv)
// 3-stage pipelined Posit multiplier
// Outputs decoded sign/scale/frac for Quire accumulator
// =============================================================================
`include "posit_pkg.vh"

module posit_mult #(
    parameter POSIT_WIDTH = `POSIT_WIDTH,
    parameter POSIT_ES    = `POSIT_ES,
    parameter DECODED_W   = 10 + POSIT_WIDTH
) (
    input  wire                         clk,
    input  wire                         resetn,
    input  wire [POSIT_WIDTH-1:0]       in_a,
    input  wire [POSIT_WIDTH-1:0]       in_b,
    output reg  [POSIT_WIDTH-1:0]       out,

    // Decoded outputs for Quire accumulator
    output reg                          out_sign,
    output reg  signed [6:0]            out_scale,
    output reg  [2*POSIT_WIDTH-1:0]     out_frac_double,
    output reg                          out_is_zero,
    output reg                          out_is_nar
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

    // --- Stage 1 Registers ---
    reg                          sign_r1;
    reg  signed [6:0]            scale_r1;
    reg                          is_zero_r1;
    reg                          is_nar_r1;
    reg  [POSIT_WIDTH-1:0]       frac_a_r1;
    reg  [POSIT_WIDTH-1:0]       frac_b_r1;

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            sign_r1    <= 1'b0;
            scale_r1   <= 7'sd0;
            is_zero_r1 <= 1'b0;
            is_nar_r1  <= 1'b0;
            frac_a_r1  <= {POSIT_WIDTH{1'b0}};
            frac_b_r1  <= {POSIT_WIDTH{1'b0}};
        end else begin
            sign_r1    <= dec_a[PD_SIGN] ^ dec_b[PD_SIGN];
            scale_r1   <= $signed(dec_a[PD_SCALE_HI:PD_SCALE_LO])
                        + $signed(dec_b[PD_SCALE_HI:PD_SCALE_LO]);
            is_zero_r1 <= dec_a[PD_IS_ZERO] || dec_b[PD_IS_ZERO];
            is_nar_r1  <= dec_a[PD_IS_NAR]  || dec_b[PD_IS_NAR];
            frac_a_r1  <= dec_a[PD_FRAC_HI:PD_FRAC_LO];
            frac_b_r1  <= dec_b[PD_FRAC_HI:PD_FRAC_LO];
        end
    end

    // --- Stage 2 Registers ---
    reg  [2*POSIT_WIDTH-1:0]     frac_prod_r2;
    reg  signed [6:0]            scale_r2;
    reg                          sign_r2;
    reg                          is_zero_r2;
    reg                          is_nar_r2;

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            frac_prod_r2 <= {(2*POSIT_WIDTH){1'b0}};
            scale_r2     <= 7'sd0;
            sign_r2      <= 1'b0;
            is_zero_r2   <= 1'b0;
            is_nar_r2    <= 1'b0;
        end else begin
            frac_prod_r2 <= frac_a_r1 * frac_b_r1;
            scale_r2     <= scale_r1;
            sign_r2      <= sign_r1;
            is_zero_r2   <= is_zero_r1;
            is_nar_r2    <= is_nar_r1;
        end
    end

    // --- Stage 3 Normalization & Encoding ---
    reg  signed [6:0]            scale_norm;
    reg  [POSIT_WIDTH-1:0]       frac_norm;
    reg  [2*POSIT_WIDTH-1:0]     frac_double_norm;

    always @(*) begin
        if (frac_prod_r2[2*POSIT_WIDTH-1]) begin
            scale_norm      = scale_r2 + 1;
            frac_double_norm = frac_prod_r2 >> 1;
        end else begin
            scale_norm      = scale_r2;
            frac_double_norm = frac_prod_r2;
        end
        frac_norm = frac_double_norm[2*POSIT_WIDTH-2 : POSIT_WIDTH-1];
    end

    // Assemble decoded struct for encoder
    wire [DECODED_W-1:0] dec_to_encode;
    assign dec_to_encode[PD_SIGN]                 = sign_r2;
    assign dec_to_encode[PD_IS_ZERO]              = is_zero_r2;
    assign dec_to_encode[PD_IS_NAR]               = is_nar_r2;
    assign dec_to_encode[PD_SCALE_HI:PD_SCALE_LO] = scale_norm;
    assign dec_to_encode[PD_FRAC_HI:PD_FRAC_LO]   = frac_norm;

    wire [POSIT_WIDTH-1:0] encoded_out;
    posit_encode #(.POSIT_WIDTH(POSIT_WIDTH), .POSIT_ES(POSIT_ES))
        encoder_inst (.in(dec_to_encode), .out(encoded_out));

    // Stage 3 Output Registers
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            out             <= {POSIT_WIDTH{1'b0}};
            out_sign        <= 1'b0;
            out_scale       <= 7'sd0;
            out_frac_double <= {(2*POSIT_WIDTH){1'b0}};
            out_is_zero     <= 1'b0;
            out_is_nar      <= 1'b0;
        end else begin
            out             <= encoded_out;
            out_sign        <= sign_r2;
            out_scale       <= scale_norm;
            out_frac_double <= frac_double_norm;
            out_is_zero     <= is_zero_r2;
            out_is_nar      <= is_nar_r2;
        end
    end

endmodule
