// =============================================================================
// dla_tb.v — Upgraded AXI & DMA Testbench running Compiled HEX instructions
// Configured for 192-bit widths (triple-packed formats)
// =============================================================================
`timescale 1ns/1ps
`include "posit_pkg.vh"
`include "strassen_pkg.vh"

module dla_tb;
    reg clk;
    reg resetn;
    integer trace_file;

    // AXI Write Address Channel
    reg [5:0]   s_axi_awaddr;
    reg         s_axi_awvalid;
    wire        s_axi_awready;

    // AXI Write Data Channel
    reg [31:0]  s_axi_wdata;
    reg [3:0]   s_axi_wstrb;
    reg         s_axi_wvalid;
    wire        s_axi_wready;

    // AXI Write Response Channel
    wire [1:0]  s_axi_bresp;
    wire        s_axi_bvalid;
    reg         s_axi_bready;

    // AXI Read Address Channel
    reg [5:0]   s_axi_araddr;
    reg         s_axi_arvalid;
    wire        s_axi_arready;

    // AXI Read Data Channel
    wire [31:0] s_axi_rdata;
    wire [1:0]  s_axi_rresp;
    wire        s_axi_rvalid;
    reg         s_axi_rready;

    // DRAM Memory Port Interface
    wire        dram_rd_en;
    wire [31:0] dram_rd_addr;
    reg [191:0] dram_rd_data;

    wire        dram_wr_en;
    wire [31:0] dram_wr_addr;
    wire [191:0] dram_wr_data;

    // Simulated off-chip System DRAM memory
    reg [191:0] dram [0:2047];

    always @(posedge clk) begin
        if (dram_rd_en) begin
            dram_rd_data <= dram[dram_rd_addr];
            // Write standard memory trace (Hex format)
            // Convert word address to byte address (multiply by 32 bytes per word)
            $fwrite(trace_file, "0x%08h R\n", dram_rd_addr * 32);
        end
    end

    always @(posedge clk) begin
        if (dram_wr_en) begin
            dram[dram_wr_addr] <= dram_wr_data;
            // Write standard memory trace (Hex format)
            $fwrite(trace_file, "0x%08h W\n", dram_wr_addr * 32);
        end
    end

    // Log DRAM read/write requests to Ramulator trace file
    always @(posedge clk) begin
        if (resetn) begin
            if (dram_rd_en) begin
                $fdisplay(trace_file, "0x%h R", dram_rd_addr * 32);
            end
            if (dram_wr_en) begin
                $fdisplay(trace_file, "0x%h W", dram_wr_addr * 32);
            end
        end
    end

    // Instantiate DLA top module
    dla_axi_wrapper #(
        .SZI(8),
        .SZJ(8),
        .POSIT_WIDTH(`POSIT_WIDTH),
        .POSIT_ES(1)
    ) uut (
        .s_axi_aclk(clk),
        .s_axi_aresetn(resetn),
        .s_axi_awaddr(s_axi_awaddr),
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_awready(s_axi_awready),
        .s_axi_wdata(s_axi_wdata),
        .s_axi_wvalid(s_axi_wvalid),
        .s_axi_wready(s_axi_wready),
        .s_axi_bresp(s_axi_bresp),
        .s_axi_bvalid(s_axi_bvalid),
        .s_axi_bready(s_axi_bready),
        .s_axi_araddr(s_axi_araddr),
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_arready(s_axi_arready),
        .s_axi_rdata(s_axi_rdata),
        .s_axi_rresp(s_axi_rresp),
        .s_axi_rvalid(s_axi_rvalid),
        .s_axi_rready(s_axi_rready),
        .dram_rd_en(dram_rd_en),
        .dram_rd_addr(dram_rd_addr),
        .dram_rd_data(dram_rd_data),
        .dram_wr_en(dram_wr_en),
        .dram_wr_addr(dram_wr_addr),
        .dram_wr_data(dram_wr_data)
    );

    // Clock generation (100 MHz)
    always #5 clk = ~clk;

    // Temporary buffers to hold matrices
    reg [191:0] temp_a [0:2047];
    reg [191:0] temp_b [0:2047];

    integer load_idx, out_file;
    integer cmd_file;
    integer scan_status;

    reg [31:0] cmd_type;
    reg [31:0] reg_addr;
    reg [31:0] val;
    reg [31:0] poll_val;

    // AXI Bus Transaction Tasks (Deterministic)
    task axi_write;
        input [5:0] addr;
        input [31:0] data;
        begin
            s_axi_awaddr = addr;
            s_axi_awvalid = 1;
            #10;
            s_axi_awvalid = 0;

            s_axi_wdata = data;
            s_axi_wvalid = 1;
            #10;
            s_axi_wvalid = 0;

            s_axi_bready = 1;
            #10;
            s_axi_bready = 0;
            #10;
        end
    endtask

    task axi_read;
        input [5:0] addr;
        output [31:0] data;
        begin
            s_axi_araddr = addr;
            s_axi_arvalid = 1;
            #10;
            s_axi_arvalid = 0;

            s_axi_rready = 1;
            #10;
            data = s_axi_rdata;
            s_axi_rready = 0;
            #10;
        end
    endtask

    // Timeout check
    initial begin
        #1200000;
        $display("[TIMEOUT] Simulation took too long!");
        if (out_file != 0) $fclose(out_file);
        if (trace_file != 0) $fclose(trace_file);
        $finish;
    end

    initial begin
        // Read file contents
        $readmemh("input_a.txt", temp_a);
        $readmemh("input_b.txt", temp_b);

        out_file = $fopen("dla_output_c.txt", "w");
        if (out_file == 0) begin
            $display("[ERR] Could not open dla_output_c.txt");
            $finish;
        end

        trace_file = $fopen("ramulator_trace.txt", "w");
        if (trace_file == 0) begin
            $display("[ERR] Could not open ramulator_trace.txt");
            $finish;
        end

        // Pre-load weight and activation matrices into system DRAM
        // Matrix B (Weights) -> DRAM address 0 to NUM_WORDS-1
        $display("[DEBUG] Loading Weight Matrix B into simulated DRAM...");
        for (load_idx = 0; load_idx < `NUM_WORDS; load_idx = load_idx + 1) begin
            dram[load_idx] = temp_b[load_idx];
        end

        // Matrix A (Activations) -> DRAM address NUM_WORDS to 2*NUM_WORDS - 1
        $display("[DEBUG] Loading Activation Matrix A into simulated DRAM...");
        for (load_idx = 0; load_idx < `NUM_WORDS; load_idx = load_idx + 1) begin
            dram[`NUM_WORDS + load_idx] = temp_a[load_idx];
        end

        clk = 0;
        resetn = 0;
        s_axi_awaddr = 0;
        s_axi_awvalid = 0;
        s_axi_wdata = 0;
        s_axi_wstrb = 0;
        s_axi_wvalid = 0;
        s_axi_bready = 0;
        s_axi_araddr = 0;
        s_axi_arvalid = 0;
        s_axi_rready = 0;

        #40;
        resetn = 1;
        $display("[DEBUG] resetn set to 1 at Time=%0d ns", $time);
        #20;

        // Open instruction file
        cmd_file = $fopen("dla_program.hex", "r");
        if (cmd_file == 0) begin
            $display("[ERR] Could not open dla_program.hex");
            $finish;
        end

        // --- Step 1: Parse and execute hex commands dynamically ---
        $display("[DEBUG] AXI: Executing compiled program from dla_program.hex...");
        scan_status = $fscanf(cmd_file, "%d %x %x\n", cmd_type, reg_addr, val);
        while (scan_status == 3) begin
            if (cmd_type == 0) begin
                // WRITE transaction
                axi_write(reg_addr[5:0], val);
            end else if (cmd_type == 1) begin
                // POLL transaction
                poll_val = 0;
                while ((poll_val & val) != val) begin
                    axi_read(reg_addr[5:0], poll_val);
                    #100;
                end
            end
            scan_status = $fscanf(cmd_file, "%d %x %x\n", cmd_type, reg_addr, val);
        end
        $fclose(cmd_file);
        $display("[SUCCESS] AXI: Program execution complete!");

        // --- Step 2: Read back final accumulated output from DRAM ---
        $display("[DEBUG] Reading back results from DRAM...");
        for (load_idx = 0; load_idx < `NUM_WORDS; load_idx = load_idx + 1) begin
            $fwrite(out_file, "%h\n", dram[2*`NUM_WORDS + load_idx]);
            $display("[DEBUG] DRAM Row %0d: %h", load_idx, dram[2*`NUM_WORDS + load_idx]);
        end

        #100;
        $fclose(out_file);
        $fclose(trace_file);
        $display("[SUCCESS] DLA Compiled Program Simulation finished successfully!");
        $finish;
    end
endmodule
