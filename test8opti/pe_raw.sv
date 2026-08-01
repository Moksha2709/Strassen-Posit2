module pe#(
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
    
    top #(.N(N),.es(es)) inst (
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
    
//    assign dotProduct = outZero ? '0 : finalSum;
        
endmodule
