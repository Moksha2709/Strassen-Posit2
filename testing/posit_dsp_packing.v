module dsp_packing#(
    parameter N = 4,
    parameter es = 3
)(
    input  [N-1:0] A_1,
    input  [N-1:0] B_1,
    input  [N-1:0] A_2,
    input  [N-1:0] B_2,
    input  [N-1:0] A_3,
    input  [N-1:0] B_3,
    
    input          clk,
    output [(2*(N))+1:0] mult_result_1_final,mult_result_2_final,mult_result_3_final

);

    wire [47:0] P_internal, P_o;
   
    wire [(2*N)-1:0] A_test_1,A_test_2,A_test_3;
   
    wire [2:0] C_test_mux [2:0];
    
    wire [2:0] C_final_padding [2:0];
    
    wire MSB;
    
    wire [26:0] A_packed;
    wire [17:0] B_packed;
    wire [47:0] C_packed;
    
    wire [1:0] sum_2bit_0;
    wire [1:0] sum_2bit_1;
    wire [1:0] sum_2bit_2;

    DSP48E2 #(
      .AMULTSEL("A"),
      .A_INPUT("DIRECT"),
      .BMULTSEL("B"),
      .B_INPUT("DIRECT"),
      .PREADDINSEL("A"),
      .RND(48'h000000000000),
      .USE_MULT("MULTIPLY"),
      .USE_SIMD("ONE48"),
      .USE_WIDEXOR("FALSE"),
      .XORSIMD("XOR24_48_96"),
      .AUTORESET_PATDET("NO_RESET"),
      .AUTORESET_PRIORITY("RESET"),
      .MASK(48'h3fffffffffff),
      .PATTERN(48'h000000000000),
      .SEL_MASK("MASK"),
      .SEL_PATTERN("PATTERN"),
      .USE_PATTERN_DETECT("NO_PATDET"),
      .IS_ALUMODE_INVERTED(4'b0000),
      .IS_CARRYIN_INVERTED(1'b0),
      .IS_CLK_INVERTED(1'b0),
      .IS_INMODE_INVERTED(5'b00000),
      .IS_OPMODE_INVERTED(9'b000000000),
      .IS_RSTALLCARRYIN_INVERTED(1'b0),
      .IS_RSTALUMODE_INVERTED(1'b0),
      .IS_RSTA_INVERTED(1'b0),
      .IS_RSTB_INVERTED(1'b0),
      .IS_RSTCTRL_INVERTED(1'b0),
      .IS_RSTC_INVERTED(1'b0),
      .IS_RSTD_INVERTED(1'b0),
      .IS_RSTINMODE_INVERTED(1'b0),
      .IS_RSTM_INVERTED(1'b0),
      .IS_RSTP_INVERTED(1'b0),
      .ACASCREG(0),
      .ADREG(0),
      .ALUMODEREG(0),
      .AREG(0),
      .BCASCREG(0),
      .BREG(0),
      .CARRYINREG(0),
      .CARRYINSELREG(0),
      .CREG(0),
      .DREG(0),
      .INMODEREG(0),
      .MREG(0),
      .OPMODEREG(0),
      .PREG(0)
   )
       DSP48E2_inst (
        .A({3'b0,A_packed}),
        .B(B_packed),
        .C(C_packed),
        .D(27'd0),
        .P(P_internal),
        .OPMODE(9'b000110101),
        .ALUMODE(4'b0000),
        .INMODE(5'b00000),
        .CARRYIN(1'b0),
        .CARRYINSEL(3'b000),
        .CLK(),
        .RSTA(1'b0),
        .RSTALLCARRYIN(1'b0),
        .RSTALUMODE(1'b0),
        .RSTB(1'b0),
        .RSTC(1'b0),
        .RSTCTRL(1'b0),
        .RSTD(1'b0),
        .RSTINMODE(1'b0),
        .RSTM(1'b0),
        .RSTP(1'b0),
        .CEA1(1'b0),
        .CEA2(1'b0),
        .CEAD(1'b0),
        .CEALUMODE(1'b0),
        .CEB1(1'b0),
        .CEB2(1'b0),
        .CEC(1'b0),
        .CECARRYIN(1'b0),
        .CECTRL(1'b0),
        .CED(1'b0),
        .CEINMODE(1'b0),
        .CEM(1'b0),
        .CEP(1'b0),
        .ACIN(30'd0),
        .BCIN(18'd0),
        .CARRYCASCIN(1'b0),
        .MULTSIGNIN(1'b0),
        .PCIN(48'd0),
        .ACOUT(),
        .BCOUT(),
        .CARRYCASCOUT(),
        .MULTSIGNOUT(),
        .PCOUT(),
        .CARRYOUT(),
        .PATTERNDETECT(),
        .PATTERNBDETECT(),
        .OVERFLOW(),
        .UNDERFLOW(),
        .XOROUT()
    );

    assign A_packed = {1'b0,A_3[3:1],8'b0,A_2[3:1],9'b0,A_1[3:1]};
    assign B_packed = {3'b0,B_3[3:1],3'b0,B_2[3:1],3'b0,B_1[3:1]};

    assign sum_2bit_0 = {1'b0, A_1[0]} * {1'b0, B_1[1]} + {1'b0, A_1[1]} * {1'b0, B_1[0]};
    assign C_test_mux[0] = ((A_1[0] == 1) ? (B_1[3:2]) : 0) + ((B_1[0] == 1) ? (A_1[3:2]) : 0) + C_final_padding[0][2];
    assign C_final_padding[0] = { sum_2bit_0 , A_1[0]*B_1[0]} ;
    
    assign sum_2bit_1 = {1'b0,A_2[0]}*{1'b0,B_2[1]} + {1'b0,A_2[1]}*{1'b0,B_2[0]};
    assign C_test_mux[1] = ((A_2[0] == 1'b1) ? B_2[3:2] : 2'b00) + ((B_2[0] == 1'b1) ? A_2[3:2] : 2'b00) + C_final_padding[1][2];
    assign C_final_padding[1] = { sum_2bit_1  , A_2[0]*B_2[0]} ;

    assign sum_2bit_2 = (A_3[0] * B_3[1] + A_3[1] * B_3[0]) << 1;
    assign C_test_mux[2] = ((A_3[0] == 1) ? (B_3[3:2]) : 0) + ((B_3[0] == 1) ? (A_3[3:2]) : 0) + C_final_padding[2][2] ;
    assign C_final_padding[2] = sum_2bit_2 + A_3[0]*B_3[0];
    
    assign C_packed = {10'b0,C_test_mux[2],14'b0,C_test_mux[1],15'b0,C_test_mux[0]};
    assign P_o = P_internal;
    
    assign A_test_1 = ({P_o[5:0],2'b0}) + C_final_padding[0][1:0];
    assign A_test_3 = ({P_o[40:35],2'b0}) + C_final_padding[2][1:0];
    assign A_test_2 = (({MSB,P_o[22:18],2'b0})) + C_final_padding[1][1:0] ;
    assign MSB = ((A_2[3:1] + B_2[3:1])>='d12) ? 1'b1 :1'b0;
    
    assign mult_result_1_final = {1'b1,A_test_1} + {A_1,4'b0} + {B_1,4'b0};
    assign mult_result_2_final = {1'b1,A_test_2} + {A_2,4'b0} + {B_2,4'b0};
    assign mult_result_3_final = {1'b1,A_test_3} + {A_3,4'b0} + {B_3,4'b0};

endmodule
