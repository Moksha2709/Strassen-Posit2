// File: posit_mult_part2.v

// Continuation: post-DSP operations

`timescale 1ns / 1ps
module posit_mult_part3 #(

parameter N  = 8,
parameter Bs = 3,
parameter es = 1
)(
    input            mult_s,
    input  [2*(N-es)+1:0] mult_m,
    input       inf_in, zero_in,
    input  [es-1:0]        e1,
    input  [es-1:0]        e2,
    input  [Bs+1:0]  r1, r2,
    output [N-1:0]   out,
    output           inf, zero
);



wire mult_m_ovf;
wire [2*(N-es)+1:0] mult_mN;

assign mult_m_ovf = mult_m[2*(N-es)+1];
assign mult_mN     = mult_m_ovf ? mult_m : (mult_m << 1);

assign inf = inf_in;
assign zero = zero_in;


wire [Bs+es+1:0] mult_e;
add_N_Cin #(.N(Bs+es+1)) add_exp(
    .a({r1,e1}), .b({r2,e2}), .cin(mult_m_ovf), .c(mult_e)
);

// Exponent and Regime Computation
wire [es-1:0] e_o;
wire [Bs:0]   r_o;
reg_exp_op #(.es(es), .Bs(Bs)) regop (
    .exp_o(mult_e),
    .e_o(e_o),
    .r_o(r_o)
);

// Packing and Rounding (RNE)
wire [2*N-1+3:0]tmp_o = {{N{~mult_e[es+Bs+1]}},mult_e[es+Bs+1],e_o,mult_mN[2*(N-es):2*(N-es)-(N-es-1)+1], mult_mN[2*(N-es)-(N-es-1):2*(N-es)-(N-es-1)-1], |mult_mN[2*(N-es)-(N-es-1)-2:0] }; 


//Including Regime bits in Exponent-Mantissa Packing
wire [3*N-1+3:0] tmp1_o;
DSR_right_N_S #(.N(3*N+3), .S(Bs+1)) dsr2 (.a({tmp_o,{N{1'b0}}}), .b(r_o[Bs] ? {Bs{1'b1}} : r_o), .c(tmp1_o));

wire L = tmp1_o[N+4],
     G = tmp1_o[N+3],
     R = tmp1_o[N+2],
     St = |tmp1_o[N+1:0];
wire ulp = ((G & (R | St)) | (L & G & ~(R | St)));
wire [N-1:0] rnd_ulp = {{N-1{1'b0}}, ulp};

wire [N:0] tmp1_o_rnd_ulp;
add_N #(.N(N)) add_ulp (
    .a(tmp1_o[2*N+2:N+3]),
    .b(rnd_ulp),
    .c(tmp1_o_rnd_ulp)
);

wire [N-1:0] tmp1_o_rnd = (r_o < N-es-2)
    ? tmp1_o_rnd_ulp[N-1:0]
    : tmp1_o[2*N+2:N+3];

wire [N-1:0] tmp1_oN = mult_s ? -tmp1_o_rnd : tmp1_o_rnd;
assign out = inf|zero|(~mult_mN[2*(N-es)+1]) ? {inf, {N-1{1'b0}}} : {mult_s, tmp1_oN[N-1:1]};

endmodule

// Include supporting modules for part2 below:
module add_N_Cin(a, b, cin, c);
    parameter N = 10;
    input  [N:0] a, b;
    input        cin;
    output [N:0] c;
    assign c = a + b + cin;
endmodule

module add_N(a, b, c);
    parameter N = 10;
    input  [N-1:0] a, b;
    output [N:0]  c;
    assign c = {1'b0, a} + {1'b0, b};
endmodule

module reg_exp_op(exp_o, e_o, r_o);
    parameter es = 3;
    parameter Bs = 5;
    input  [es+Bs+1:0] exp_o;
    output [es-1:0]    e_o;
    output [Bs:0]      r_o;
    
    assign e_o = exp_o[es-1:0];
    wire [es+Bs:0] exp_oN_tmp;
    conv_2c #(.N(es+Bs)) conv (
        .a(~exp_o[es+Bs:0]),
        .c(exp_oN_tmp)
    );
    wire [es+Bs:0] exp_oN = exp_o[es+Bs+1] ? exp_oN_tmp : exp_o[es+Bs:0];
    assign r_o = (~exp_o[es+Bs+1] || |exp_oN[es-1:0])
        ? exp_oN[es+Bs:es] + 1
        : exp_oN[es+Bs:es];
endmodule

module conv_2c(a, c);
    parameter N = 10;
    input  [N:0] a;
    output [N:0] c;
    assign c = a + 1'b1;
endmodule

module DSR_right_N_S(a, b, c);
    parameter N = 16;
    parameter S = 4;
    input  [N-1:0] a;
    input  [S-1:0] b;
    output [N-1:0] c;
    
    wire [N-1:0] tmp [S-1:0];
    assign tmp[0] = b[0] ? a >> 1 : a;
    genvar i;
    generate for (i = 1; i < S; i = i + 1) begin: shift_loop
        assign tmp[i] = b[i] ? tmp[i-1] >> (2**i) : tmp[i-1];
    end endgenerate
    assign c = tmp[S-1];
endmodule
