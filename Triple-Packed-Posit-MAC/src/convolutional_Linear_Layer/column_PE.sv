`timescale 1ns / 1ps


module column_PE #(
    parameter int N       = 3,                // number of rows
    parameter int M       = 4,                // number of columns
    parameter int DW      = 8,                 // data width
    parameter es = 1
)(
    input clk,
    input rst,
    input logic [DW-1:0] a_arrange [0:M-1],
    input logic [DW-1:0] b_arrange [0:M-1],
    input logic [DW-1:0] initial_cin,
    output logic [DW-1:0] column_mult
    );
    localparam int NUM_PE = (M + 2) / 3;  // Ceiling division to group into 3s
    logic [DW-1:0] sum [0:NUM_PE];
//    logic [DW-1:0] sum [M:0];
    assign sum[0]= initial_cin;

genvar i;
generate
    for (i = 0; i < NUM_PE; i++) begin : PE_BLOCK
        logic [DW-1:0] a1, a2, a3;
        logic [DW-1:0] b1, b2, b3;

        if (i == NUM_PE-1) begin
            assign a1 = (3*i < M)     ? a_arrange[3*i]     : 'd0;
            assign a2 = (3*i+1 < M)   ? a_arrange[3*i+1]   : 'd0;
            assign a3 = (3*i+2 < M)   ? a_arrange[3*i+2]   : 'd0;
            assign b1 = (3*i < M)     ? b_arrange[3*i]     : 'd0;
            assign b2 = (3*i+1 < M)   ? b_arrange[3*i+1]   : 'd0;
            assign b3 = (3*i+2 < M)   ? b_arrange[3*i+2]   : 'd0;
        end else begin
            assign a1 = a_arrange[3*i];
            assign a2 = a_arrange[3*i+1];
            assign a3 = a_arrange[3*i+2];
            assign b1 = b_arrange[3*i];
            assign b2 = b_arrange[3*i+1];
            assign b3 = b_arrange[3*i+2];
        end

        PE #(.N(DW), .es(es)) pe_inst (
            .clk(clk),
            .rst(rst),
            .a1(a1), .a2(a2), .a3(a3),
            .b1(b1), .b2(b2), .b3(b3),
            .cin(sum[i]),
            .cout(sum[i+1])
        );
    end
endgenerate

     
     assign column_mult = sum[NUM_PE];  
endmodule
