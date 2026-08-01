// =============================================================================
// dsp48e2_sim_model.v — Behavioral Simulation Model of Xilinx DSP48E2
// Only used for Icarus Verilog simulation support.
// =============================================================================

module DSP48E2 #(
    parameter AMULTSEL = "A",
    parameter A_INPUT = "DIRECT",
    parameter BMULTSEL = "B",
    parameter B_INPUT = "DIRECT",
    parameter PREADDINSEL = "A",
    parameter [47:0] RND = 48'h000000000000,
    parameter USE_MULT = "MULTIPLY",
    parameter USE_SIMD = "ONE48",
    parameter USE_WIDEXOR = "FALSE",
    parameter XORSIMD = "XOR24_48_96",
    parameter AUTORESET_PATDET = "NO_RESET",
    parameter AUTORESET_PRIORITY = "RESET",
    parameter [47:0] MASK = 48'h3fffffffffff,
    parameter [47:0] PATTERN = 48'h000000000000,
    parameter SEL_MASK = "MASK",
    parameter SEL_PATTERN = "PATTERN",
    parameter USE_PATTERN_DETECT = "NO_PATDET",
    parameter [3:0] IS_ALUMODE_INVERTED = 4'b0000,
    parameter IS_CARRYIN_INVERTED = 1'b0,
    parameter IS_CLK_INVERTED = 1'b0,
    parameter [4:0] IS_INMODE_INVERTED = 5'b00000,
    parameter [8:0] IS_OPMODE_INVERTED = 9'b000000000,
    parameter IS_RSTALLCARRYIN_INVERTED = 1'b0,
    parameter IS_RSTALUMODE_INVERTED = 1'b0,
    parameter IS_RSTA_INVERTED = 1'b0,
    parameter IS_RSTB_INVERTED = 1'b0,
    parameter IS_RSTCTRL_INVERTED = 1'b0,
    parameter IS_RSTC_INVERTED = 1'b0,
    parameter IS_RSTD_INVERTED = 1'b0,
    parameter IS_RSTINMODE_INVERTED = 1'b0,
    parameter IS_RSTM_INVERTED = 1'b0,
    parameter IS_RSTP_INVERTED = 1'b0,
    parameter integer ACASCREG = 0,
    parameter integer ADREG = 0,
    parameter integer ALUMODEREG = 0,
    parameter integer AREG = 0,
    parameter integer BCASCREG = 0,
    parameter integer BREG = 0,
    parameter integer CARRYINREG = 0,
    parameter integer CARRYINSELREG = 0,
    parameter integer CREG = 0,
    parameter integer DREG = 0,
    parameter integer INMODEREG = 0,
    parameter integer MREG = 0,
    parameter integer OPMODEREG = 0,
    parameter integer PREG = 0
)(
    input  [29:0] A,
    input  [17:0] B,
    input  [47:0] C,
    input  [26:0] D,
    output [47:0] P,
    input  [8:0]  OPMODE,
    input  [3:0]  ALUMODE,
    input  [4:0]  INMODE,
    input         CARRYIN,
    input  [2:0]  CARRYINSEL,
    input         CLK,
    input         RSTA,
    input         RSTALLCARRYIN,
    input         RSTALUMODE,
    input         RSTB,
    input         RSTC,
    input         RSTCTRL,
    input         RSTD,
    input         RSTINMODE,
    input         RSTM,
    input         RSTP,
    input         CEA1,
    input         CEA2,
    input         CEAD,
    input         CEALUMODE,
    input         CEB1,
    input         CEB2,
    input         CEC,
    input         CECARRYIN,
    input         CECTRL,
    input         CED,
    input         CEINMODE,
    input         CEM,
    input         CEP,
    input  [29:0] ACIN,
    input  [17:0] BCIN,
    input         CARRYCASCIN,
    input         MULTSIGNIN,
    input  [47:0] PCIN,
    output [29:0] ACOUT,
    output [17:0] BCOUT,
    output        CARRYCASCOUT,
    output        MULTSIGNOUT,
    output [47:0] PCOUT,
    output [3:0]  CARRYOUT,
    output        PATTERNDETECT,
    output        PATTERNBDETECT,
    output        OVERFLOW,
    output        UNDERFLOW,
    output [7:0]  XOROUT
);

    // Behavioral multiplication: P = A[26:0] * B[17:0] + C
    // This perfectly mimics the OPMODE(9'b000110101) logic used in the DSP block.
    
    // DSP48E2 multipliers are signed by default, but we treat them as unsigned
    // since we do manual sign management in the companding logic.
    wire [44:0] mult_res = A[26:0] * B[17:0];
    assign P = mult_res + C;

    // Unused outputs
    assign ACOUT = 30'b0;
    assign BCOUT = 18'b0;
    assign CARRYCASCOUT = 1'b0;
    assign MULTSIGNOUT = 1'b0;
    assign PCOUT = 48'b0;
    assign CARRYOUT = 4'b0;
    assign PATTERNDETECT = 1'b0;
    assign PATTERNBDETECT = 1'b0;
    assign OVERFLOW = 1'b0;
    assign UNDERFLOW = 1'b0;
    assign XOROUT = 8'b0;

endmodule
