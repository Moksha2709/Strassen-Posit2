`timescale 1ns / 1ps

module posit_dsp_part2 #(
    parameter N = 8,
    parameter es = 1,
    parameter Bs = 3
)(
    input  [N-es:0]        m1_1,
    input  [N-es:0]        m1_2,
    input  [N-es:0]        m2_1,
    input  [N-es:0]        m2_2,
    input  [N-es:0]        m3_1,
    input  [N-es:0]        m3_2,

    input                  clk,  // Required for DSP block

    output [2*(N-es)+1:0]  mult_m_1,
    output [2*(N-es)+1:0]  mult_m_2,
    output [2*(N-es)+1:0]  mult_m_3

    );

    // Slice bits from mantissas for DSP input (assuming 4-bit multiplier)
    wire [(2*(N-es-3))+1:0] mult_result_1,mult_result_2,mult_result_3;  // 4-bit x 4-bit = up to 8 bits (plus carry)

    wire [N-es-4:0] m1_dsp_in_1,m1_dsp_in_2,m2_dsp_in_1,m2_dsp_in_2,m3_dsp_in_1,m3_dsp_in_2;
    
    assign m1_dsp_in_1 = m1_1[N-es-1:3];
    assign m1_dsp_in_2 = m1_2[N-es-1:3];  
    assign m2_dsp_in_1 = m2_1[N-es-1:3];
    assign m2_dsp_in_2 = m2_2[N-es-1:3];
    assign m3_dsp_in_1 = m3_1[N-es-1:3];
    assign m3_dsp_in_2 = m3_2[N-es-1:3]; 

    // Instantiate DSP multiplier (called 'top' but ideally should be named better)
    dsp_packing #(
        .N(4),
        .es(es)
    ) u_dsp_mult (
        .A_1({{(es){1'b0}},m1_dsp_in_1}),
        .B_1({{(es){1'b0}},m1_dsp_in_2}),
        .A_2({{(es){1'b0}},m2_dsp_in_1}),
        .B_2({{(es){1'b0}},m2_dsp_in_2}),
        .A_3({{(es){1'b0}},m3_dsp_in_1}),
        .B_3({{(es){1'b0}},m3_dsp_in_2}),
        .clk(clk),
        .mult_result_1_final(mult_result_1),
        .mult_result_2_final(mult_result_2),  // Unused
        .mult_result_3_final(mult_result_3)   // Unused
    );

    
  


    // Assign DSP output to lower bits of mult_m, upper bits padded with 0
    assign mult_m_1 = {mult_result_1, 6'b0 };  // Zero-extend to match mult_m width
    assign mult_m_2 = {mult_result_2, 6'b0 };  // Zero-extend to match mult_m width
    assign mult_m_3 = {mult_result_3, 6'b0 };  // Zero-extend to match mult_m width

endmodule
