// =============================================================================
// posit_pe.v — Verilog (Delayed Normalization Architecture with Scale Tracking)
// Dedicated 3-Way Triple-Packed Posit Processing Element
// Accumulates mantissas into 10-bit integer accumulators with dynamic scale tracking.
// Uses simple 1-way right-shift for scale alignment.
// Optimized 36-bit activation bus / 48-bit readout bus footprint with 100% DSP execution.
// =============================================================================
`include "posit_pkg.vh"

module posit_pe (
    input  wire                         clk,
    input  wire                         resetn,

    // Control signals
    input  wire                         load_weight,
    input  wire                         clear_quire,
    input  wire                         shift_out,
    input  wire                         shift_load,

    // Data paths (3-channel trimmed buses)
    input  wire [35:0]                  posit_in_a,    // Activations (from west): 3x 12-bit decoded Posits
    input  wire [47:0]                  posit_in_b,    // Weights/Shift-in (from north): 3x 16-bit formatted words
    output wire [35:0]                  posit_out_a,   // Activations (to east)
    output wire [47:0]                  posit_out_b    // Weights/Shift-out (to south)
);

    // Pipeline registers
    reg [35:0] act_reg;
    reg [35:0] weight_reg;
    reg [47:0] readout_reg;

    // Raw Unshifted Integer Accumulators (10-bit signed accumulators per channel)
    reg signed [9:0] accum_reg1;  // Channel 1
    reg signed [9:0] accum_reg2;  // Channel 2
    reg signed [9:0] accum_reg3;  // Channel 3

    // Scale Registers to track running maximum scale per channel
    reg signed [5:0] scale_reg1;
    reg signed [5:0] scale_reg2;
    reg signed [5:0] scale_reg3;

    // Extract low channel decoded structs
    wire [11:0] act1_dec = act_reg[11:0];
    wire [11:0] act2_dec = act_reg[23:12];
    wire [11:0] act3_dec = act_reg[35:24];

    wire [11:0] w1_dec  = weight_reg[11:0];
    wire [11:0] w2_dec  = weight_reg[23:12];
    wire [11:0] w3_dec  = weight_reg[35:24];

    // Extract mantissas
    wire [3:0] A1_mant = act1_dec[3:0];
    wire [3:0] A2_mant = act2_dec[3:0];
    wire [3:0] A3_mant = act3_dec[3:0];

    wire [3:0] W1_mant = w1_dec[3:0];
    wire [3:0] W2_mant = w2_dec[3:0];
    wire [3:0] W3_mant = w3_dec[3:0];

    // =========================================================================
    // Multipliers Unit — Tri-Product DSP48E2 Packing Architecture
    // Performs 3-way packed mantissa multiplication using a single 27x18 multiplier
    // =========================================================================

    // 1. Bit splitting for 4-bit mantissas (MSB: 3 bits [3:1], LSB: 1 bit [0])
    wire [2:0] a1_msb = A1_mant[3:1];
    wire [2:0] a2_msb = A2_mant[3:1];
    wire [2:0] a3_msb = A3_mant[3:1];

    wire [2:0] w1_msb = W1_mant[3:1];
    wire [2:0] w2_msb = W2_mant[3:1];
    wire [2:0] w3_msb = W3_mant[3:1];

    // 2. Port Packing: A = (w3 << 24) | (w2 << 12) | w1 (27 bits), B = (a3 << 12) | (a2 << 6) | a1 (15 bits)
    wire [26:0] A_packed = {1'b0, w3_msb, 8'b0, w2_msb, 9'b0, w1_msb};
    wire [17:0] B_packed = {3'b0, a3_msb, 3'b0, a2_msb, 3'b0, a1_msb};

    // 3. LSB Cross-Term Packing into C-Port
    wire [1:0] sum_2bit_0 = {1'b0, A1_mant[0]} * {1'b0, W1_mant[1]} + {1'b0, A1_mant[1]} * {1'b0, W1_mant[0]};
    wire [2:0] C_final_padding_0 = {sum_2bit_0, A1_mant[0] * W1_mant[0]};
    wire [2:0] C_test_mux_0 = ((A1_mant[0] == 1'b1) ? W1_mant[3:2] : 2'b00) + ((W1_mant[0] == 1'b1) ? A1_mant[3:2] : 2'b00) + C_final_padding_0[2];

    wire [1:0] sum_2bit_1 = {1'b0, A2_mant[0]} * {1'b0, W2_mant[1]} + {1'b0, A2_mant[1]} * {1'b0, W2_mant[0]};
    wire [2:0] C_final_padding_1 = {sum_2bit_1, A2_mant[0] * W2_mant[0]};
    wire [2:0] C_test_mux_1 = ((A2_mant[0] == 1'b1) ? W2_mant[3:2] : 2'b00) + ((W2_mant[0] == 1'b1) ? A2_mant[3:2] : 2'b00) + C_final_padding_1[2];

    wire [2:0] sum_2bit_2 = (A3_mant[0] * W3_mant[1] + A3_mant[1] * W3_mant[0]) << 1;
    wire [2:0] C_final_padding_2 = sum_2bit_2 + (A3_mant[0] * W3_mant[0]);
    wire [2:0] C_test_mux_2 = ((A3_mant[0] == 1'b1) ? W3_mant[3:2] : 2'b00) + ((W3_mant[0] == 1'b1) ? A3_mant[3:2] : 2'b00) + C_final_padding_2[2];

    wire [47:0] C_packed = {10'b0, C_test_mux_2, 14'b0, C_test_mux_1, 15'b0, C_test_mux_0};

    wire [47:0] P_internal;

`ifdef SIMULATION
    assign P_internal = (A_packed * B_packed) + C_packed;
`else
    DSP48E2 #(
        .AMULTSEL("A"), .A_INPUT("DIRECT"), .BMULTSEL("B"), .B_INPUT("DIRECT"), .PREADDINSEL("A"),
        .RND(48'h000000000000), .USE_MULT("MULTIPLY"), .USE_SIMD("ONE48"), .USE_WIDEXOR("FALSE"),
        .XORSIMD("XOR24_48_96"), .AUTORESET_PATDET("NO_RESET"), .AUTORESET_PRIORITY("RESET"),
        .MASK(48'h3fffffffffff), .PATTERN(48'h000000000000), .SEL_MASK("MASK"), .SEL_PATTERN("PATTERN"),
        .USE_PATTERN_DETECT("NO_PATDET"), .IS_ALUMODE_INVERTED(4'b0000), .IS_CARRYIN_INVERTED(1'b0),
        .IS_CLK_INVERTED(1'b0), .IS_INMODE_INVERTED(5'b00000), .IS_OPMODE_INVERTED(9'b000000000),
        .IS_RSTALLCARRYIN_INVERTED(1'b0), .IS_RSTALUMODE_INVERTED(1'b0), .IS_RSTA_INVERTED(1'b0),
        .IS_RSTB_INVERTED(1'b0), .IS_RSTCTRL_INVERTED(1'b0), .IS_RSTC_INVERTED(1'b0), .IS_RSTD_INVERTED(1'b0),
        .IS_RSTINMODE_INVERTED(1'b0), .IS_RSTM_INVERTED(1'b0), .IS_RSTP_INVERTED(1'b0),
        .ACASCREG(0), .ADREG(0), .ALUMODEREG(0), .AREG(0), .BCASCREG(0), .BREG(0),
        .CARRYINREG(0), .CARRYINSELREG(0), .CREG(0), .DREG(0), .INMODEREG(0),
        .MREG(0), .OPMODEREG(0), .PREG(0)
    ) DSP48E2_inst (
        .A({3'b0, A_packed}), .B(B_packed), .C(C_packed), .D(27'd0), .P(P_internal),
        .OPMODE(9'b000110101), .ALUMODE(4'b0000), .INMODE(5'b00000), .CARRYIN(1'b0),
        .CARRYINSEL(3'b000), .CLK(1'b0), .RSTA(1'b0), .RSTALLCARRYIN(1'b0), .RSTALUMODE(1'b0),
        .RSTB(1'b0), .RSTC(1'b0), .RSTCTRL(1'b0), .RSTD(1'b0), .RSTINMODE(1'b0), .RSTM(1'b0), .RSTP(1'b0),
        .CEA1(1'b0), .CEA2(1'b0), .CEAD(1'b0), .CEALUMODE(1'b0), .CEB1(1'b0), .CEB2(1'b0),
        .CEC(1'b0), .CECARRYIN(1'b0), .CECTRL(1'b0), .CED(1'b0), .CEINMODE(1'b0), .CEM(1'b0), .CEP(1'b0),
        .ACIN(30'd0), .BCIN(18'd0), .CARRYCASCIN(1'b0), .MULTSIGNIN(1'b0), .PCIN(48'd0),
        .ACOUT(), .BCOUT(), .CARRYCASCOUT(), .MULTSIGNOUT(), .PCOUT(), .CARRYOUT(),
        .PATTERNDETECT(), .PATTERNBDETECT(), .OVERFLOW(), .UNDERFLOW(), .XOROUT()
    );
`endif

    // 4. Extraction of Products with Carry Cancellation (100% DSP execution)
    wire [7:0] P1_exact = {P_internal[5:0], C_final_padding_0[1:0]};

    // Channel 2 Carry Cancellation from shift 12
    wire [5:0] sum_shift12 = (w2_msb * a1_msb) + (w1_msb * a3_msb) + ((w1_msb * a2_msb) >> 6);
    wire [1:0] carry_t2 = sum_shift12 >> 6;
    wire [5:0] p2_msb_exact = P_internal[23:18] - carry_t2;
    wire [7:0] P2_exact = {p2_msb_exact, C_final_padding_1[1:0]};

    wire [7:0] P3_exact = {P_internal[40:35], C_final_padding_2[1:0]};

    // =========================================================================
    // Scale and Sign Calculation
    // =========================================================================
    wire signed [5:0] scale1  = $signed(act1_dec[9:4])  + $signed(w1_dec[9:4]);
    wire signed [5:0] scale2  = $signed(act2_dec[9:4])  + $signed(w2_dec[9:4]);
    wire signed [5:0] scale3  = $signed(act3_dec[9:4])  + $signed(w3_dec[9:4]);

    wire sign1  = act1_dec[11]  ^ w1_dec[11];
    wire sign2  = act2_dec[11]  ^ w2_dec[11];
    wire sign3  = act3_dec[11]  ^ w3_dec[11];

    wire is_zero1 = act1_dec[10] || w1_dec[10];
    wire is_zero2 = act2_dec[10] || w2_dec[10];
    wire is_zero3 = act3_dec[10] || w3_dec[10];

    // Convert unshifted 8-bit product to signed 10-bit integer format
    wire signed [9:0] prod1 = is_zero1 ? 10'sd0 : (sign1 ? -$signed({2'b0, P1_exact}) : $signed({2'b0, P1_exact}));
    wire signed [9:0] prod2 = is_zero2 ? 10'sd0 : (sign2 ? -$signed({2'b0, P2_exact}) : $signed({2'b0, P2_exact}));
    wire signed [9:0] prod3 = is_zero3 ? 10'sd0 : (sign3 ? -$signed({2'b0, P3_exact}) : $signed({2'b0, P3_exact}));

    // =========================================================================
    // Accumulation logic with Dynamic Running Scale Alignment (1-way right shift)
    // =========================================================================
    function automatic [15:0] update_accum (
        input signed [9:0] old_accum,
        input signed [5:0] old_scale,
        input signed [9:0] new_prod,
        input signed [5:0] new_scale
    );
        reg signed [5:0] diff;
        reg signed [9:0] updated_accum;
        reg signed [5:0] updated_scale;
        begin
            if (new_prod == 10'sd0) begin
                updated_accum = old_accum;
                updated_scale = old_scale;
            end else if (old_accum == 10'sd0) begin
                updated_accum = new_prod;
                updated_scale = new_scale;
            end else if (new_scale >= old_scale) begin
                diff = new_scale - old_scale;
                if (diff > 6'sd8) diff = 6'sd8;
                updated_accum = ($signed(old_accum) >>> $signed({1'b0, diff[3:0]})) + new_prod;
                updated_scale = new_scale;
            end else begin
                diff = old_scale - new_scale;
                if (diff > 6'sd8) diff = 6'sd8;
                updated_accum = old_accum + ($signed(new_prod) >>> $signed({1'b0, diff[3:0]}));
                updated_scale = old_scale;
            end
            update_accum = {updated_scale, updated_accum};
        end
    endfunction

    wire [15:0] res1 = update_accum(accum_reg1, scale_reg1, prod1, scale1);
    wire [15:0] res2 = update_accum(accum_reg2, scale_reg2, prod2, scale2);
    wire [15:0] res3 = update_accum(accum_reg3, scale_reg3, prod3, scale3);

    always @(posedge clk or negedge resetn) begin
        if (!resetn || clear_quire) begin
            accum_reg1 <= 10'sd0;
            accum_reg2 <= 10'sd0;
            accum_reg3 <= 10'sd0;
            scale_reg1 <= 6'sd0;
            scale_reg2 <= 6'sd0;
            scale_reg3 <= 6'sd0;
        end else begin
            accum_reg1 <= res1[9:0];
            scale_reg1 <= res1[15:10];
            accum_reg2 <= res2[9:0];
            scale_reg2 <= res2[15:10];
            accum_reg3 <= res3[9:0];
            scale_reg3 <= res3[15:10];
        end
    end

    // =========================================================================
    // Systolic Registers and Readout Logic (16-bit formatted channel readout)
    // =========================================================================
    wire [15:0] ch1_word = {scale_reg1, accum_reg1};
    wire [15:0] ch2_word = {scale_reg2, accum_reg2};
    wire [15:0] ch3_word = {scale_reg3, accum_reg3};

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            act_reg     <= 36'b0;
            weight_reg  <= 36'b0;
            readout_reg <= 48'b0;
        end else begin
            act_reg <= posit_in_a;
            
            if (load_weight)
                weight_reg <= posit_in_b[35:0];

            if (shift_load)
                readout_reg <= {ch3_word, ch2_word, ch1_word};
            else if (shift_out)
                readout_reg <= posit_in_b;
        end
    end

    assign posit_out_a = act_reg;
    assign posit_out_b = shift_out ? readout_reg : {12'b0, weight_reg};

endmodule
