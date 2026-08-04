// =============================================================================
// strassen_tb.v — Standard Verilog Testbench for strassen_top simulation
// =============================================================================
`timescale 1ns/1ps
`include "posit_pkg.vh"
`include "strassen_pkg.vh"

module strassen_tb;
    reg clk;
    reg resetn;
    reg start;
    wire done;

    reg input_a_val;
    reg [191:0] input_a_data;
    wire input_a_rdy;

    reg input_b_val;
    reg [191:0] input_b_data;
    wire input_b_rdy;

    wire out_val;
    wire [191:0] out_data;
    reg out_rdy;

    // Instantiate the top-level wrapper
    strassen_top #(
        .SZI(8),
        .SZJ(8),
        .POSIT_WIDTH(8),
        .POSIT_ES(1)
    ) uut (
        .clk(clk),
        .resetn(resetn),
        .start(start),
        .done(done),
        .input_a_val(input_a_val),
        .input_a_data(input_a_data),
        .input_a_rdy(input_a_rdy),
        .input_b_val(input_b_val),
        .input_b_data(input_b_data),
        .input_b_rdy(input_b_rdy),
        .out_val(out_val),
        .out_data(out_data),
        .out_rdy(out_rdy)
    );

    // Clock generator (100 MHz clock)
    always #5 clk = ~clk;

    integer tile_idx, row_idx;

    initial begin
        clk = 0;
        resetn = 0;
        start = 0;
        input_a_val = 0;
        input_a_data = 0;
        input_b_val = 0;
        input_b_data = 0;
        out_rdy = 1;

        #40;
        resetn = 1;
        #20;

        // Assert start to initiate matrix loading
        $display("[TB] Asserting start to load matrices...");
        start = 1;
        #10;
        start = 0;

        // Stream 4 tiles of A and 4 tiles of B (each tile has 8 rows of 8 elements)
        for (tile_idx = 0; tile_idx < 4; tile_idx = tile_idx + 1) begin
            for (row_idx = 0; row_idx < 8; row_idx = row_idx + 1) begin
                while (!(input_a_rdy && input_b_rdy)) begin
                    #10;
                end
                
                input_a_val = 1;
                input_b_val = 1;
                
                input_a_data = {24{8'h40}};
                input_b_data = {24{8'h40}};
                
                #10;
                input_a_val = 0;
                input_b_val = 0;
            end
        end

        $display("[TB] Inputs loaded. FSM is running the Strassen loops...");

        fork
            begin
                while (!done) begin
                    if (out_val && out_rdy) begin
                        $display("[TB] Output C Row: %h", out_data);
                    end
                    #10;
                end
            end
        join

        $display("[TB] Done received! Simulation finished successfully.");
        #100;
        $finish;
    end
endmodule
