// =============================================================================
// dla_sram_ping_pong.v — Verilog
// Dual-bank ping-pong SRAM module enabling simultaneous DMA load and MXU compute
// =============================================================================

module dla_sram_ping_pong #(
    parameter WIDTH = 192,
    parameter DEPTH = 64
) (
    input  wire                             clk,
    input  wire                             bank_sel, // 0: Bank0=Compute / Bank1=DMA; 1: Bank1=Compute / Bank0=DMA

    // DMA Port (Writes next matrix tile from DRAM)
    input  wire                             dma_wr_en,
    input  wire [$clog2(DEPTH)-1:0]         dma_addr,
    input  wire [WIDTH-1:0]                 dma_data_in,

    // Execution Compute Port (Reads current matrix tile into MXU Array)
    input  wire                             exec_rd_en,
    input  wire [$clog2(DEPTH)-1:0]         exec_addr,
    output reg  [WIDTH-1:0]                 exec_data_out,

    // Output Write-back Port (Writes compute results)
    input  wire                             exec_wr_en,
    input  wire [$clog2(DEPTH)-1:0]         exec_wr_addr,
    input  wire [WIDTH-1:0]                 exec_wr_data
);

    reg [WIDTH-1:0] bank0 [0:DEPTH-1];
    reg [WIDTH-1:0] bank1 [0:DEPTH-1];

    integer i;
    initial begin
        for (i = 0; i < DEPTH; i = i + 1) begin
            bank0[i] = {WIDTH{1'b0}};
            bank1[i] = {WIDTH{1'b0}};
        end
    end

    // DMA Write Routing
    always @(posedge clk) begin
        if (dma_wr_en) begin
            if (bank_sel == 1'b0) begin
                bank1[dma_addr] <= dma_data_in; // Load into Bank 1 while computing Bank 0
            end else begin
                bank0[dma_addr] <= dma_data_in; // Load into Bank 0 while computing Bank 1
            end
        end
    end

    // Execution Read Routing
    always @(posedge clk) begin
        if (exec_rd_en) begin
            if (bank_sel == 1'b0) begin
                exec_data_out <= bank0[exec_addr]; // Compute from Bank 0
            end else begin
                exec_data_out <= bank1[exec_addr]; // Compute from Bank 1
            end
        end
    end

    // Execution Write-back Routing
    always @(posedge clk) begin
        if (exec_wr_en) begin
            if (bank_sel == 1'b0) begin
                bank0[exec_wr_addr] <= exec_wr_data;
            end else begin
                bank1[exec_wr_addr] <= exec_wr_data;
            end
        end
    end

endmodule
