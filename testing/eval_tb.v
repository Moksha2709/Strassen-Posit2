// =============================================================================
// eval_tb.v — Testbench for Triple-Packed & 4-bit SIMD 8-bit Posit Strassen
// Drives either 3 parallel 8-bit streams or 6 parallel 4-bit streams.
// Controlled dynamically via command line plusarg.
// =============================================================================
`timescale 1ns/1ps
`include "posit_pkg.vh"
`include "strassen_pkg.vh"

module eval_tb;
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

    // Instantiate strassen_top
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

    // Clock generation (100 MHz)
    always #5 clk = ~clk;

    // Memory buffers to hold the input test vectors (32 rows, each row has 8 packed columns)
    reg [191:0] mem_a [0:31];
    reg [191:0] mem_b [0:31];
    
    integer tile_idx, row_idx, load_idx, out_cnt;
    integer out_file;

    // Simulation Timeout
    initial begin
        #400000;
        $display("[TIMEOUT] Simulation took too long!");
        if (out_file != 0) $fclose(out_file);
        $finish;
    end

    initial begin        $display("[TB INFO] Starting simulation");

        // Read input hex files
        $readmemh("input_a.txt", mem_a);
        $readmemh("input_b.txt", mem_b);
        
        out_file = $fopen("output_c.txt", "w");
        if (out_file == 0) begin
            $display("[ERR] Could not open output_c.txt");
            $finish;
        end

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
        $display("[DEBUG] resetn set to 1 at Time=%0d ns", $time);
        #20;

        start = 1;
        $display("[DEBUG] start set to 1 at Time=%0d ns", $time);
        #10;
        start = 0;
        $display("[DEBUG] start set to 0 at Time=%0d ns", $time);

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

        // Monitor outputs and write them to output_c.txt
        out_cnt = 0;
        while (out_cnt < 32) begin
            if (out_val && out_rdy) begin
                $fwrite(out_file, "%h\n", out_data);
                out_cnt = out_cnt + 1;
            end
            #10;
        end

        #100;
        $fclose(out_file);
        $finish;
    end
endmodule
