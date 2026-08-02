module PE#(
    parameter N = 8,
    parameter es = 1
)(  
    input clk,
    input rst,
    input [N-1:0] a1,a2,a3,
    input [N-1:0] b1,b2,b3,
    input [N-1:0] cin,
    // input ldKernel,
    output logic [N-1:0] cout
    );
    
    logic [N-1:0] finalSum, outTemp;
    logic outZero, zeroTemp;
    logic [N-1:0] prev_i_reg;
    
    always_ff @(posedge clk, posedge rst) begin
        if(rst) cout <= '0;
        else cout <= outZero ? '0 : finalSum;
    end
    
    MAC_top #(.N(N),.es(es)) inst (
        .in1({a3,a2,a1}), 
        .in2({b3,b2,b1}),
        .clk(clk),
        .rst(rst),
        .final_out_wire(outTemp),
        .zero_final_wire(zeroTemp),
        .inf_final_wire()
    );
    
    posit_add #(.N(N), .es(es)) add_inst (
        .in1(zeroTemp ? '0 : outTemp),
        .in2(cin),
        .out(finalSum),
        .inf(),
        .zero(outZero)
    );
    
//    assign cout = outZero ? '0 : finalSum;
        
endmodule

//`timescale 1ns / 1ps

//module PE#(
//    parameter DW = 8
//)(
//    input  logic              clk,
//    input rst,
//    input  logic [DW-1:0]     a1, a2, a3,
//    input  logic [DW-1:0]     b1, b2, b3,
//    input  logic [DW-1:0]     cin,
//    output logic [DW-1:0]     cout
//);

//    logic [DW-1:0] sum;
////    logic [2:0] count = 0;

//    always_ff @(posedge clk) begin
//        sum <= (a1 * b1) + (a2 * b2) + (a3 * b3) + cin;
////        count <= count+1;
////        if(count == 2) count <= 0; 
//    end

//    assign cout = sum;

//endmodule
