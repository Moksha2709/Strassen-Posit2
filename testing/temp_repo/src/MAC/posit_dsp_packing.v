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
    
//    input  [N-1:0] C_i,
    input          clk,
    output [(2*(N))+1:0] mult_result_1_final,mult_result_2_final,mult_result_3_final // 4-bit x 4-bit = up to 8 bits (plus carry)

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
      // Feature Control Attributes: Data Path Selection
      .AMULTSEL("A"),                    // Selects A input to multiplier (A, AD)
      .A_INPUT("DIRECT"),                // Selects A input source, "DIRECT" (A port) or "CASCADE" (ACIN port)
      .BMULTSEL("B"),                    // Selects B input to multiplier (AD, B)
      .B_INPUT("DIRECT"),                // Selects B input source, "DIRECT" (B port) or "CASCADE" (BCIN port)
      .PREADDINSEL("A"),                 // Selects input to pre-adder (A, B)
      .RND(48'h000000000000),            // Rounding Constant
      .USE_MULT("MULTIPLY"),             // Select multiplier usage (DYNAMIC, MULTIPLY, NONE)
      .USE_SIMD("ONE48"),                // SIMD selection (FOUR12, ONE48, TWO24)
      .USE_WIDEXOR("FALSE"),             // Use the Wide XOR function (FALSE, TRUE)
      .XORSIMD("XOR24_48_96"),           // Mode of operation for the Wide XOR (XOR12, XOR24_48_96)
      // Pattern Detector Attributes: Pattern Detection Configuration
      .AUTORESET_PATDET("NO_RESET"),     // NO_RESET, RESET_MATCH, RESET_NOT_MATCH
      .AUTORESET_PRIORITY("RESET"),      // Priority of AUTORESET vs. CEP (CEP, RESET).
      .MASK(48'h3fffffffffff),           // 48-bit mask value for pattern detect (1=ignore)
      .PATTERN(48'h000000000000),        // 48-bit pattern match for pattern detect
      .SEL_MASK("MASK"),                 // C, MASK, ROUNDING_MODE1, ROUNDING_MODE2
      .SEL_PATTERN("PATTERN"),           // Select pattern value (C, PATTERN)
      .USE_PATTERN_DETECT("NO_PATDET"),  // Enable pattern detect (NO_PATDET, PATDET)
      // Programmable Inversion Attributes: Specifies built-in programmable inversion on specific pins
      .IS_ALUMODE_INVERTED(4'b0000),     // Optional inversion for ALUMODE
      .IS_CARRYIN_INVERTED(1'b0),        // Optional inversion for CARRYIN
      .IS_CLK_INVERTED(1'b0),            // Optional inversion for CLK
      .IS_INMODE_INVERTED(5'b00000),     // Optional inversion for INMODE
      .IS_OPMODE_INVERTED(9'b000000000), // Optional inversion for OPMODE
      .IS_RSTALLCARRYIN_INVERTED(1'b0),  // Optional inversion for RSTALLCARRYIN
      .IS_RSTALUMODE_INVERTED(1'b0),     // Optional inversion for RSTALUMODE
      .IS_RSTA_INVERTED(1'b0),           // Optional inversion for RSTA
      .IS_RSTB_INVERTED(1'b0),           // Optional inversion for RSTB
      .IS_RSTCTRL_INVERTED(1'b0),        // Optional inversion for RSTCTRL
      .IS_RSTC_INVERTED(1'b0),           // Optional inversion for RSTC
      .IS_RSTD_INVERTED(1'b0),           // Optional inversion for RSTD
      .IS_RSTINMODE_INVERTED(1'b0),      // Optional inversion for RSTINMODE
      .IS_RSTM_INVERTED(1'b0),           // Optional inversion for RSTM
      .IS_RSTP_INVERTED(1'b0),           // Optional inversion for RSTP
      // Register Control Attributes: Pipeline Register Configuration
      .ACASCREG(0),                      // Number of pipeline stages between A/ACIN and ACOUT (0-2)
      .ADREG(0),                         // Pipeline stages for pre-adder (0-1)
      .ALUMODEREG(0),                    // Pipeline stages for ALUMODE (0-1)
      .AREG(0),                          // Pipeline stages for A (0-2)
      .BCASCREG(0),                      // Number of pipeline stages between B/BCIN and BCOUT (0-2)
      .BREG(0),                          // Pipeline stages for B (0-2)
      .CARRYINREG(0),                    // Pipeline stages for CARRYIN (0-1)
      .CARRYINSELREG(0),                 // Pipeline stages for CARRYINSEL (0-1)
      .CREG(0),                          // Pipeline stages for C (0-1)
      .DREG(0),                          // Pipeline stages for D (0-1)
      .INMODEREG(0),                     // Pipeline stages for INMODE (0-1)
      .MREG(0),                          // Multiplier pipeline stages (0-1)
      .OPMODEREG(0),                     // Pipeline stages for OPMODE (0-1)
      .PREG(0)                           // Number of pipeline stages for P (0-1)
   )
       DSP48E2_inst (
        .A({3'b0,A_packed}),        // 30-bit padded input A
        .B(B_packed),        // 18-bit padded input B
        .C(C_packed),                    
        .D(27'd0),                    // Unused
        .P(P_internal),              // 48-bit product output

        // Constant control signals for pure multiplication
        .OPMODE(9'b000110101),       // Z = A * B
        .ALUMODE(4'b0000),
        .INMODE(5'b00000),
        .CARRYIN(1'b0),
        .CARRYINSEL(3'b000),

        // Disable clock and reset
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

        // Enable paths to avoid optimization
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

        // Unused cascade ports (tie to 0)
        .ACIN(30'd0),
        .BCIN(18'd0),
        .CARRYCASCIN(1'b0),
        .MULTSIGNIN(1'b0),
        .PCIN(48'd0),

        // Ignore unused outputs
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
    
    
    
    
assign C_test_mux[1] = 
    ((A_2[0] == 1'b1) ? B_2[3:2] : 2'b00) + 
    ((B_2[0] == 1'b1) ? A_2[3:2] : 2'b00) + 
    C_final_padding[1][2] ;
    
//    - (((A_2[3:1] * B_1[3:1]) + (A_1[3:1] * B_3[3:1]) > 'd63) ? 1'b1 : 1'b0);   //carry logic
//    assign C_final_padding[1] = {(({1'b0,A_2[0]}*{1'b0,B_2[1]} + {1'b0,A_2[1]}*{1'b0,B_2[0]}) && 2'b11), A_2[0]*B_2[0]} ;
    assign C_final_padding[1] = { sum_2bit_1  , A_2[0]*B_2[0]} ;


//    assign sum_2bit_2 = {1'b0, A_3[0]} * {1'b0, B_3[1]} + {1'b0, A_3[1]} * {1'b0, B_3[0]};

    assign sum_2bit_2 =  (A_3[0] *  B_3[1] + A_3[1] * B_3[0]) << 1;




    assign C_test_mux[2] = ((A_3[0] == 1) ? (B_3[3:2]) : 0) + ((B_3[0] == 1) ? (A_3[3:2]) : 0) + C_final_padding[2][2] ;    
    assign C_final_padding[2] =  sum_2bit_2 + A_3[0]*B_3[0] ;
    
    
    assign C_packed = {10'b0,C_test_mux[2],14'b0,C_test_mux[1],15'b0,C_test_mux[0]};


    assign P_o = P_internal;  // Truncate or slice as required
    
//    assign A_test_1 = (P_o[5:0] << 2) + C_final_padding[0][1:0];
//    assign A_test_3 = (P_o[40:35] << 2) + C_final_padding[2][1:0];

    assign A_test_1 = ({P_o[5:0],2'b0}) + C_final_padding[0][1:0];
    assign A_test_3 = ({P_o[40:35],2'b0}) + C_final_padding[2][1:0];


    assign A_test_2 = (({MSB,P_o[22:18],2'b0})) + C_final_padding[1][1:0] ;
    assign MSB = ((A_2[3:1] + B_2[3:1])>='d12) ? 1'b1 :1'b0;
    
    
    
//    assign mult_result_1_final = {1'b1,A_test_1} + (A_1 << (N)) + (B_1 << (N));
    
//    assign mult_result_2_final = {1'b1,A_test_2} + (A_2 << (N)) + (B_2 << (N));
    
//    assign mult_result_3_final = {1'b1,A_test_3} + (A_3 << (N)) + (B_3 << (N));


    assign mult_result_1_final = {1'b1,A_test_1} +  {A_1,4'b0} + {B_1,4'b0};
    
    assign mult_result_2_final = {1'b1,A_test_2} + {A_2, 4'b0} + {B_2,4'b0};
    
    assign mult_result_3_final = {1'b1,A_test_3} + {A_3 ,4'b0} + {B_3 ,4'b0};
    

endmodule