// File: posit_mult_part1.v
`timescale 1ns / 1ps
//(* use_dsp = "no" *)
module posit_mult_part1(
    in1, in2,
    m1, m2,r1,r2,e1,e2,mult_s,
    inf, zero
);

//function [31:0] log2;
//    input reg [31:0] value;
//    begin
//        value = value-1;
//        for (log2 = 0; value > 0; log2 = log2 + 1)
//            value = value >> 1;
//    end
//endfunction

parameter N  = 8;
parameter Bs = $clog2(N);
parameter es = 1;

input  [N-1:0] in1, in2;
output [N-es:0] m1, m2;
output        mult_s;
output [Bs+1:0] r1,r2;
output [es-1:0] e1, e2;
output        inf, zero;



wire s1      = in1[N-1];
wire s2      = in2[N-1];

wire zero_tmp1 = |in1[N-2:0];
wire zero_tmp2 = |in2[N-2:0];

wire inf1 = s1 & (~zero_tmp1),
     inf2 = s2 & (~zero_tmp2);
wire zero1 = ~(s1 | zero_tmp1),
     zero2 = ~(s2 | zero_tmp2);

assign inf  = inf1 | inf2;
assign zero = zero1 & zero2;

// Data Extraction
wire rc1, rc2;
wire [Bs-1:0] regime1, regime2;
wire [N-es-1:0] mant1, mant2;

wire [N-1:0] xin1 = s1 ? -in1 : in1;
wire [N-1:0] xin2 = s2 ? -in2 : in2;

data_extract_v1 #(.N(N), .es(es)) uut_de1(
    .in(xin1), .rc(rc1), .regime(regime1), .exp(e1), .mant(mant1)
);
data_extract_v1 #(.N(N), .es(es)) uut_de2(
    .in(xin2), .rc(rc2), .regime(regime2), .exp(e2), .mant(mant2)
);

// Prepare mantissa for DSP
assign m1 = {zero_tmp1, mant1};
assign m2 = {zero_tmp2, mant2};

assign mult_s = s1 ^ s2;

assign r1 = rc1 ? {2'b0,regime1} : -regime1;
assign r2 = rc2 ? {2'b0,regime2} : -regime2;

// Expose done

endmodule


// Include the data extraction module in this file
module data_extract_v1 #(
    parameter N  = 8,
    parameter es = 1,
    parameter Bs = $clog2(N)
)(
    input  [N-1:0] in,
    output        rc,
    output [Bs-1:0] regime,
    output [es-1:0] exp,
    output [N-es-1:0] mant
);

//function [31:0] log2;
//    input reg [31:0] value;
//    begin
//        value = value-1;
//        for (log2 = 0; value > 0; log2 = log2 + 1)
//            value = value >> 1;
//    end
//endfunction



wire [N-1:0] xin = in;
assign rc = xin[N-2];

wire [N-1:0] xin_r = rc ? ~xin : xin;

wire [Bs-1:0] k;
LOD_N #(.N(N)) lod_inst(
    .in({xin_r[N-2:0], rc ^ 1'b0}),
    .out(k)
);

assign regime = rc ? k-1 : k;

wire [N-1:0] xin_tmp;
DSR_left_N_S #(.N(N), .S(Bs)) ls (
    .a({xin[N-3:0], 2'b00}),
    .b(k),
    .c(xin_tmp)
);

assign exp  = xin_tmp[N-1:N-es];
assign mant = xin_tmp[N-es-1:0];

endmodule


// LOD and shift modules declarations needed for part1
module LOD_N (in, out);

//  function [31:0] log2;
//    input reg [31:0] value;
//    begin
//      value = value-1;
//      for (log2=0; value>0; log2=log2+1)
//	value = value>>1;
//    end
//  endfunction

parameter N = 8;
parameter S = $clog2(N); 
input [N-1:0] in;
output [S-1:0] out;

wire vld;
LOD #(.N(N)) l1 (in, out, vld);
endmodule




module LOD (in, out, vld);

//  function [31:0] log2;
//    input reg [31:0] value;
//    begin
//      value = value-1;
//      for (log2=0; value>0; log2=log2+1)
//	value = value>>1;
//    end
//  endfunction


parameter N = 8;
parameter S = $clog2(N);

   input [N-1:0] in;
   output [S-1:0] out;
   output vld;

  generate
    if (N == 2)
      begin
	assign vld = |in;
	assign out = ~in[1] & in[0];
      end
    else if (N & (N-1))
      //LOD #(1<<S) LOD ({1<<S {1'b0}} | in,out,vld);
      LOD #(1<<S) LOD ({in,{((1<<S) - N) {1'b0}}},out,vld);
    else
      begin
	wire [S-2:0] out_l, out_h;
	wire out_vl, out_vh;
	LOD #(N>>1) l(in[(N>>1)-1:0],out_l,out_vl);
	LOD #(N>>1) h(in[N-1:N>>1],out_h,out_vh);
	assign vld = out_vl | out_vh;
	assign out = out_vh ? {1'b0,out_h} : {out_vl,out_l};
      end
  endgenerate
endmodule



module DSR_left_N_S(a,b,c);
        parameter N=8;
        parameter S=$clog2(N);
        input [N-1:0] a;
        input [S-1:0] b;
        output [N-1:0] c;

wire [N-1:0] tmp [S-1:0];
assign tmp[0]  = b[0] ? a << 7'd1  : a; 
genvar i;
generate
	for (i=1; i<S; i=i+1)begin:loop_blk
		assign tmp[i] = b[i] ? tmp[i-1] << 2**i : tmp[i-1];
	end
endgenerate
assign c = tmp[S-1];

endmodule
