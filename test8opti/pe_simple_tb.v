`timescale 1ns/1ps
`include "posit_pkg.vh"

module pe_simple_tb;
    reg clk;
    reg resetn;
    reg load_weight;
    reg clear_quire;
    reg shift_out;
    reg shift_load;

    reg [23:0] posit_in_a;
    reg [47:0] posit_in_b;
    wire [23:0] posit_out_a;
    wire [47:0] posit_out_b;

    posit_pe uut (
        .clk(clk),
        .resetn(resetn),
        .load_weight(load_weight),
        .clear_quire(clear_quire),
        .shift_out(shift_out),
        .shift_load(shift_load),
        .posit_in_a(posit_in_a),
        .posit_in_b(posit_in_b),
        .posit_out_a(posit_out_a),
        .posit_out_b(posit_out_b)
    );

    always #5 clk = ~clk;

    // Monitor internal signals inside UUT (with a small 1ns delay so registers have settled)
    always @(posedge clk) begin
        #1;
        $display("[CLOCK EDGE Time=%0d ns]", $time);
        $display("  act_reg     = 0x%h | weight_reg = 0x%h", uut.act_reg, uut.weight_reg);
        $display("  prod1       = 0x%h | prod1_fixed = 0x%h", uut.prod1, uut.prod1_fixed);
        $display("  accum_reg1  = 0x%h | readout_reg = 0x%h", uut.accum_reg1, uut.readout_reg);
    end

    initial begin
        clk = 0;
        resetn = 0;
        load_weight = 0;
        clear_quire = 0;
        shift_out = 0;
        shift_load = 0;
        posit_in_a = 24'b0;
        posit_in_b = 48'b0;

        #20;
        resetn = 1;
        #10;

        // Load Weights into PE (Weight = 1.0 in Q12.4 is 16'h0010)
        posit_in_b = {16'h0010, 16'h0010, 16'h0010};
        load_weight = 1;
        #10;
        load_weight = 0;
        posit_in_b = 48'b0;
        #10;

        // Feed Activations (1.0 in raw Posit is 8'h40)
        posit_in_a = {8'h40, 8'h40, 8'h40};
        #10;
        
        // Feed next cycle
        posit_in_a = {8'h40, 8'h40, 8'h40};
        #10;
        posit_in_a = 24'b0;
        #20;

        // Shift Load Accumulators to Readout Register
        shift_load = 1;
        #10;
        shift_load = 0;
        #10;

        // Shift Out outputs to south edge
        shift_out = 1;
        #1; // Read immediately before the clock edge overwrites readout_reg
        $display("[TB RESULT] shifted_out_accumulators = 0x%h", posit_out_b);
        if (posit_out_b == {16'h0020, 16'h0020, 16'h0020}) begin
            $display("[TB SUCCESS] Hybrid Posit-Multiplier / Fixed-Point Accumulator PE verified successfully!");
        end else begin
            $display("[TB FAILED] Mismatch! Got 0x%h, Expected 0x002000200020", posit_out_b);
        end
        shift_out = 0;

        #20;
        $finish;
    end
endmodule
