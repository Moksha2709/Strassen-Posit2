// =============================================================================
// verify_16bit_hardware_cycles.v — Multi-Tile Cycle Counter Testbench for 16bittest
// -----------------------------------------------------------------------------
// Measures exact Verilog hardware clock cycles for 16-bit fixed-point Strassen GEMM
// across multiple continuous tiles back-to-back.
// =============================================================================
`timescale 1ns/1ps
`include "fixed_pkg.vh"
`include "strassen_pkg.vh"

module verify_16bit_hardware_cycles;
    reg clk;
    reg resetn;
    reg start;
    wire done;

    reg input_a_val;
    reg [127:0] input_a_data;
    wire input_a_rdy;

    reg input_b_val;
    reg [127:0] input_b_data;
    wire input_b_rdy;

    wire out_val;
    wire [127:0] out_data;
    reg out_rdy;

    // Cycle Counter Register
    reg [31:0] cycle_count;
    reg [31:0] tile_start_cycles;
    reg [31:0] compute_cycles_sum;

    strassen_top #(
        .SZI(8),
        .SZJ(8),
        .DATA_WIDTH(16),
        .FRAC_WIDTH(8)
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

    // Clock generation (10 ns period = 100 MHz simulation clock)
    always #5 clk = ~clk;

    // Always block for Cycle Counter
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            cycle_count <= 0;
        end else begin
            cycle_count <= cycle_count + 1;
        end
    end

    reg [127:0] mem_a [0:31];
    reg [127:0] mem_b [0:31];
    integer tile_idx, row_idx, load_idx, out_cnt;
    integer t_test;

    initial begin
        $readmemh("input_a.txt", mem_a);
        $readmemh("input_b.txt", mem_b);

        clk = 0;
        resetn = 0;
        start = 0;
        input_a_val = 0;
        input_a_data = 0;
        input_b_val = 0;
        input_b_data = 0;
        out_rdy = 1;
        compute_cycles_sum = 0;

        #40;
        resetn = 1;
        #20;

        $display("\n================================================================================");
        $display("  VERILOG HARDWARE CYCLE LOGGER (16BITTEST 16-BIT FIXED STRASSEN DLA)");
        $display("================================================================================\n");

        // Loop over 3 continuous GEMM tiles to measure exact hardware execution latency
        for (t_test = 0; t_test < 3; t_test = t_test + 1) begin
            tile_start_cycles = cycle_count;

            start = 1;
            #10;
            start = 0;

            load_idx = 0;
            for (tile_idx = 0; tile_idx < 4; tile_idx = tile_idx + 1) begin
                for (row_idx = 0; row_idx < 8; row_idx = row_idx + 1) begin
                    while (!(input_a_rdy && input_b_rdy)) begin
                        #10;
                    end
                    
                    input_a_val = 1;
                    input_b_val = 1;
                    input_a_data = mem_a[load_idx];
                    input_b_data = mem_b[load_idx];
                    
                    #10;
                    input_a_val = 0;
                    input_b_val = 0;
                    load_idx = load_idx + 1;
                end
            end

            out_cnt = 0;
            while (out_cnt < 32) begin
                if (out_val && out_rdy) begin
                    out_cnt = out_cnt + 1;
                end
                #10;
            end

            $display("[CYCLES] Tile %0d Hardware Execution Latency: %0d clock cycles", 
                     t_test, cycle_count - tile_start_cycles);
            compute_cycles_sum = compute_cycles_sum + (cycle_count - tile_start_cycles);
            #100;
        end

        $display("\n================================================================================");
        $display("  3-TILE HARDWARE SUMMARY (16BITTEST)");
        $display("  Total Hardware Cycles for 3 Tiles  : %0d cycles", compute_cycles_sum);
        $display("  Average Measured Latency per Tile  : %0d cycles/tile", compute_cycles_sum / 3);
        $display("================================================================================\n");

        $finish;
    end
endmodule
