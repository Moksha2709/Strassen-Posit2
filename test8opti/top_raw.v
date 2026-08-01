//`timescale 1ns / 1ps


//module top #(
//    parameter N = 8,
//    parameter es = 1,
//    parameter Bs = $clog2(N)
//)(
//    input  [(3*N)-1:0] in1, in2,
//    input              clk,
//    output [N-1:0]     out_1,
//    output             inf_1,
//    output             zero_1,
//    output [N-1:0]     out_2,
//    output             inf_2,
//    output             zero_2,
//    output [N-1:0]     out_3,
//    output             inf_3,
//    output             zero_3,
//    output [N-1:0]     final_out,     // Final output after addition
//    output             inf_final,
//    output             zero_final
//);

//    wire [N-es:0] m1_1, m1_2, m2_1, m2_2, m3_1, m3_2;
//    wire [Bs+1:0] r1_1, r2_1, r1_2, r2_2, r1_3, r2_3;
//    wire [es-1:0] e1_1, e2_1, e1_2, e2_2, e1_3, e2_3;
//    wire          mult_s_1, mult_s_2, mult_s_3;
//    wire          zero_wire_1, zero_wire_2, zero_wire_3;
//    wire          inf_wire_1, inf_wire_2, inf_wire_3;

//    wire [N-1:0] in1_1 = in1[N-1:0];
//    wire [N-1:0] in1_2 = in1[2*N-1:N];
//    wire [N-1:0] in1_3 = in1[3*N-1:2*N];

//    wire [N-1:0] in2_1 = in2[N-1:0];
//    wire [N-1:0] in2_2 = in2[2*N-1:N];
//    wire [N-1:0] in2_3 = in2[3*N-1:2*N];

//    posit_mult_part1 #(.N(N), .es(es), .Bs(Bs)) u_part1_1 (
//        .in1(in1_1), .in2(in2_1),
//        .m1(m1_1), .m2(m1_2),
//        .r1(r1_1), .r2(r2_1),
//        .e1(e1_1), .e2(e2_1),
//        .mult_s(mult_s_1),
//        .inf(inf_wire_1),
//        .zero(zero_wire_1)
//    );

//    posit_mult_part1 #(.N(N), .es(es), .Bs(Bs)) u_part1_2 (
//        .in1(in1_2), .in2(in2_2),
//        .m1(m2_1), .m2(m2_2),
//        .r1(r1_2), .r2(r2_2),
//        .e1(e1_2), .e2(e2_2),
//        .mult_s(mult_s_2),
//        .inf(inf_wire_2),
//        .zero(zero_wire_2)
//    );

//    posit_mult_part1 #(.N(N), .es(es), .Bs(Bs)) u_part1_3 (
//        .in1(in1_3), .in2(in2_3),
//        .m1(m3_1), .m2(m3_2),
//        .r1(r1_3), .r2(r2_3),
//        .e1(e1_3), .e2(e2_3),
//        .mult_s(mult_s_3),
//        .inf(inf_wire_3),
//        .zero(zero_wire_3)
//    );

//    wire [2*(N-es)+1:0] mult_m_1, mult_m_2, mult_m_3;

//    posit_dsp_part2 #(.N(N), .es(es), .Bs(Bs)) u_part2 (
//        .m1_1(m1_1), .m1_2(m1_2),
//        .m2_1(m2_1), .m2_2(m2_2),
//        .m3_1(m3_1), .m3_2(m3_2),
//        .clk(clk),
//        .mult_m_1(mult_m_1),
//        .mult_m_2(mult_m_2),
//        .mult_m_3(mult_m_3)
//    );

//    posit_mult_part3 #(.N(N), .es(es), .Bs(Bs)) u_part3_1 (
//        .mult_s(mult_s_1),
//        .inf_in(inf_wire_1),
//        .zero_in(zero_wire_1),
//        .mult_m(mult_m_1),
//        .e1(e1_1), .e2(e2_1),
//        .r1(r1_1), .r2(r2_1),
//        .out(out_1),
//        .inf(inf_1),
//        .zero(zero_1)
//    );

//    posit_mult_part3 #(.N(N), .es(es), .Bs(Bs)) u_part3_2 (
//        .mult_s(mult_s_2),
//        .inf_in(inf_wire_2),
//        .zero_in(zero_wire_2),
//        .mult_m(mult_m_2),
//        .e1(e1_2), .e2(e2_2),
//        .r1(r1_2), .r2(r2_2),
//        .out(out_2),
//        .inf(inf_2),
//        .zero(zero_2)
//    );

//    posit_mult_part3 #(.N(N), .es(es), .Bs(Bs)) u_part3_3 (
//        .mult_s(mult_s_3),
//        .inf_in(inf_wire_3),
//        .zero_in(zero_wire_3),
//        .mult_m(mult_m_3),
//        .e1(e1_3), .e2(e2_3),
//        .r1(r1_3), .r2(r2_3),
//        .out(out_3),
//        .inf(inf_3),
//        .zero(zero_3)
//    );


//    // ---------- Addition of out_1 + out_2 ----------
//    wire [N-1:0] out_temp;
//    wire         inf_temp, zero_temp, done_temp;

//    posit_add #(.N(N), .es(es)) u_add1 (
//        .in1(out_1),
//        .in2(out_2),
//        .out(out_temp),
//        .inf(inf_temp),
//        .zero(zero_temp)
//    );

//    // ---------- Addition of out_temp + out_3 ----------
//    posit_add #(.N(N), .es(es)) u_add2 (
//        .in1(out_temp),
//        .in2(out_3),
//        .out(final_out),
//        .inf(inf_final),
//        .zero(zero_final)
//    );
    

    

//endmodule






`timescale 1ns / 1ps
//(* use_dsp = "no" *)

module top #(
    parameter N = 8,
    parameter es = 1,
    parameter Bs = $clog2(N)
)(
    input  [(3*N)-1:0] in1, 
    input  [(3*N)-1:0] in2,
    input              clk,
    input              rst,

//    output reg [N-1:0] out_1,
//    output reg         inf_1,
//    output reg         zero_1,

//    output reg [N-1:0] out_2,
//    output reg         inf_2,
//    output reg         zero_2,

//    output reg [N-1:0] out_3,
//    output reg         inf_3,
//    output reg         zero_3,

//    output reg [N-1:0] final_out,     // Final output after addition
//    output reg         inf_final,
//    output reg         zero_final
    output wire [N-1:0] final_out_wire,
    output wire         inf_final_wire, 
    output wire         zero_final_wire
);

    wire [N-es:0] m1_1, m1_2, m2_1, m2_2, m3_1, m3_2;
    wire [Bs+1:0] r1_1, r2_1, r1_2, r2_2, r1_3, r2_3;
    wire [es-1:0] e1_1, e2_1, e1_2, e2_2, e1_3, e2_3;
    wire          mult_s_1, mult_s_2, mult_s_3;
    wire          zero_wire_1, zero_wire_2, zero_wire_3;
    wire          inf_wire_1, inf_wire_2, inf_wire_3;
    
    
    
    // Internal registers to hold input values
    reg [(3*N)-1:0] in1_reg, in2_reg;
    
    // Register the inputs
    always @(posedge clk) begin
        in1_reg <= in1;
        in2_reg <= in2;
    end
    
    reg [N-1:0] out_1;
    reg         inf_1;
    reg         zero_1;

    reg [N-1:0] out_2;
    reg         inf_2;
    reg         zero_2;

    reg [N-1:0] out_3;
    reg         inf_3;
    reg         zero_3;

    
    
    

    wire [N-1:0] in1_1 = in1_reg[N-1:0];
    wire [N-1:0] in1_2 = in1_reg[2*N-1:N];
    wire [N-1:0] in1_3 = in1_reg[3*N-1:2*N];

    wire [N-1:0] in2_1 = in2_reg[N-1:0];
    wire [N-1:0] in2_2 = in2_reg[2*N-1:N];
    wire [N-1:0] in2_3 = in2_reg[3*N-1:2*N];

    posit_mult_part1 #(.N(N), .es(es), .Bs(Bs)) u_part1_1 (
        .in1(in1_1), .in2(in2_1),
        .m1(m1_1), .m2(m1_2),
        .r1(r1_1), .r2(r2_1),
        .e1(e1_1), .e2(e2_1),
        .mult_s(mult_s_1),
        .inf(inf_wire_1),
        .zero(zero_wire_1)
    );

    posit_mult_part1 #(.N(N), .es(es), .Bs(Bs)) u_part1_2 (
        .in1(in1_2), .in2(in2_2),
        .m1(m2_1), .m2(m2_2),
        .r1(r1_2), .r2(r2_2),
        .e1(e1_2), .e2(e2_2),
        .mult_s(mult_s_2),
        .inf(inf_wire_2),
        .zero(zero_wire_2)
    );

    posit_mult_part1 #(.N(N), .es(es), .Bs(Bs)) u_part1_3 (
        .in1(in1_3), .in2(in2_3),
        .m1(m3_1), .m2(m3_2),
        .r1(r1_3), .r2(r2_3),
        .e1(e1_3), .e2(e2_3),
        .mult_s(mult_s_3),
        .inf(inf_wire_3),
        .zero(zero_wire_3)
    );

    wire [2*(N-es)+1:0] mult_m_1, mult_m_2, mult_m_3;

    posit_dsp_part2 #(.N(N), .es(es), .Bs(Bs)) u_part2 (
        .m1_1(m1_1), .m1_2(m1_2),
        .m2_1(m2_1), .m2_2(m2_2),
        .m3_1(m3_1), .m3_2(m3_2),
        .clk(clk),
        .mult_m_1(mult_m_1),
        .mult_m_2(mult_m_2),
        .mult_m_3(mult_m_3)
    );

    wire [N-1:0] out_1_wire, out_2_wire, out_3_wire;
    wire        inf_1_wire, inf_2_wire, inf_3_wire;
    wire        zero_1_wire, zero_2_wire, zero_3_wire;

    posit_mult_part3 #(.N(N), .es(es), .Bs(Bs)) u_part3_1 (
        .mult_s(mult_s_1),
        .inf_in(inf_wire_1),
        .zero_in(zero_wire_1),
        .mult_m(mult_m_1),
        .e1(e1_1), .e2(e2_1),
        .r1(r1_1), .r2(r2_1),
        .out(out_1_wire),
        .inf(inf_1_wire),
        .zero(zero_1_wire)
    );

    posit_mult_part3 #(.N(N), .es(es), .Bs(Bs)) u_part3_2 (
        .mult_s(mult_s_2),
        .inf_in(inf_wire_2),
        .zero_in(zero_wire_2),
        .mult_m(mult_m_2),
        .e1(e1_2), .e2(e2_2),
        .r1(r1_2), .r2(r2_2),
        .out(out_2_wire),
        .inf(inf_2_wire),
        .zero(zero_2_wire)
    );

    posit_mult_part3 #(.N(N), .es(es), .Bs(Bs)) u_part3_3 (
        .mult_s(mult_s_3),
        .inf_in(inf_wire_3),
        .zero_in(zero_wire_3),
        .mult_m(mult_m_3),
        .e1(e1_3), .e2(e2_3),
        .r1(r1_3), .r2(r2_3),
        .out(out_3_wire),
        .inf(inf_3_wire),
        .zero(zero_3_wire)
    );

    // ---------- Addition of out_1 + out_2 ----------
    wire [N-1:0] out_temp;
    wire         inf_temp, zero_temp;

    posit_add #(.N(N), .es(es)) u_add1 (
        .in1(out_1_wire),
        .in2(out_2_wire),
        .out(out_temp),
        .inf(inf_temp),
        .zero(zero_temp)
    );

    // ---------- Addition of out_temp + out_3 ----------
//    wire [N-1:0] final_out_wire;
//    wire         inf_final_wire, zero_final_wire;

    posit_add #(.N(N), .es(es)) u_add2 (
        .in1(out_temp),
        .in2(out_3_wire),
        .out(final_out_wire),
        .inf(inf_final_wire),
        .zero(zero_final_wire)
    );

    // ---------- Register Outputs ----------
//    always @(posedge clk, posedge rst) begin
//        if(rst) begin
//            out_1      <= 0;
//            inf_1      <= 0;
//            zero_1     <= 0;
    
//            out_2      <= 0;
//            inf_2      <= 0;
//            zero_2     <= 0;
    
//            out_3      <= 0;
//            inf_3      <= 0;
//            zero_3     <= 0;
    
//            final_out  <= 0;
//            inf_final  <= 0;
//            zero_final <= 0;
//        end
//        else begin
//            out_1      <= out_1_wire;
//            inf_1      <= inf_1_wire;
//            zero_1     <= zero_1_wire;
    
//            out_2      <= out_2_wire;
//            inf_2      <= inf_2_wire;
//            zero_2     <= zero_2_wire;
    
//            out_3      <= out_3_wire;
//            inf_3      <= inf_3_wire;
//            zero_3     <= zero_3_wire;
    
//            final_out  <= final_out_wire;
//            inf_final  <= inf_final_wire;
//            zero_final <= zero_final_wire;
//        end
//    end

endmodule
