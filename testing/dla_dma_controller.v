// =============================================================================
// dla_dma_controller.v — Verilog
// Pipelined DMA controller for DLA memory transfers
// Configured for 192-bit width for triple-packed formats
// =============================================================================

module dla_dma_controller (
    input  wire                             clk,
    input  wire                             resetn,

    // AXI Control inputs
    input  wire [31:0]                      dma_sys_addr,
    input  wire [7:0]                       dma_sram_addr, // [6:0]: Row addr, [7]: Sel (0: Act, 1: Weight)
    input  wire [5:0]                       dma_len,
    input  wire                             dma_start,
    input  wire                             dma_dir,       // 0: Sys->SRAM, 1: SRAM->Sys
    output reg                              dma_busy,
    output reg                              dma_done,

    // External System Memory (DRAM) Interface (Master read/write)
    output reg                              sys_rd_en,
    output reg [31:0]                       sys_rd_addr,
    input  wire [191:0]                     sys_rd_data,

    output reg                              sys_wr_en,
    output reg [31:0]                       sys_wr_addr,
    output reg [191:0]                      sys_wr_data,

    // DLA SRAM Buffer Port A Interface (Master read/write)
    output reg                              dma_sram_wr_en,
    output reg [6:0]                        dma_sram_addr_val,
    output reg [191:0]                      dma_sram_wr_data,

    output reg                              dma_sram_rd_en,
    input  wire [191:0]                     dma_sram_rd_data,
    output wire                             dma_sram_sel
);

    // Registered configuration parameters
    reg [31:0] dma_sys_addr_reg;
    reg [7:0]  dma_sram_addr_reg;
    reg [5:0]  dma_len_reg;
    reg        dma_dir_reg;

    reg [5:0] rd_cnt;
    reg [5:0] wr_cnt;
    reg       active_pipe;
    reg       active_pipe_d1;

    assign dma_sram_sel = dma_sram_addr_reg[7];

    localparam [0:0]
        DMA_STATE_IDLE     = 1'b0,
        DMA_STATE_TRANSFER = 1'b1;

    reg state;

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            state              <= DMA_STATE_IDLE;
            dma_busy           <= 1'b0;
            dma_done           <= 1'b0;
            dma_sys_addr_reg   <= 32'd0;
            dma_sram_addr_reg  <= 8'd0;
            dma_len_reg        <= 6'd0;
            dma_dir_reg        <= 1'b0;
            rd_cnt             <= 6'd0;
            wr_cnt             <= 6'd0;
            active_pipe        <= 1'b0;
            active_pipe_d1     <= 1'b0;
            sys_rd_en          <= 1'b0;
            sys_rd_addr        <= 32'd0;
            sys_wr_en          <= 1'b0;
            sys_wr_addr        <= 32'd0;
            sys_wr_data        <= 192'd0;
            dma_sram_wr_en     <= 1'b0;
            dma_sram_addr_val  <= 7'd0;
            dma_sram_wr_data   <= 192'd0;
            dma_sram_rd_en     <= 1'b0;
        end else begin
            dma_done <= 1'b0;

            case (state)
                DMA_STATE_IDLE: begin
                    dma_busy <= 1'b0;
                    rd_cnt   <= 6'd0;
                    wr_cnt   <= 6'd0;
                    active_pipe <= 1'b0;
                    if (dma_start) begin
                        dma_sys_addr_reg  <= dma_sys_addr;
                        dma_sram_addr_reg <= dma_sram_addr;
                        dma_len_reg       <= dma_len;
                        dma_dir_reg       <= dma_dir;
                        dma_busy          <= 1'b1;
                        state             <= DMA_STATE_TRANSFER;
                    end
                end

                DMA_STATE_TRANSFER: begin
                    // 1. Read Request phase
                    if (rd_cnt < dma_len_reg) begin
                        rd_cnt      <= rd_cnt + 6'd1;
                        active_pipe <= 1'b1;
                        if (dma_dir_reg == 1'b0) begin
                            // Sys -> SRAM: Request read from System Memory
                            sys_rd_en   <= 1'b1;
                            sys_rd_addr <= dma_sys_addr_reg + rd_cnt;
                        end else begin
                            // SRAM -> Sys: Request read from SRAM Port A
                            dma_sram_rd_en    <= 1'b1;
                            dma_sram_addr_val <= dma_sram_addr_reg[6:0] + rd_cnt;
                        end
                    end else begin
                        sys_rd_en      <= 1'b0;
                        dma_sram_rd_en <= 1'b0;
                        active_pipe    <= 1'b0;
                    end

                    // 2. Write phase (delayed by 2 cycles relative to read request)
                    active_pipe_d1 <= active_pipe;
                    if (active_pipe_d1) begin
                        wr_cnt <= wr_cnt + 6'd1;
                        if (dma_dir_reg == 1'b0) begin
                            // Sys -> SRAM: Write fetched word into SRAM Port A
                            dma_sram_wr_en    <= 1'b1;
                            dma_sram_addr_val <= dma_sram_addr_reg[6:0] + wr_cnt;
                            dma_sram_wr_data  <= sys_rd_data;
                        end else begin
                            // SRAM -> Sys: Write fetched word into System Memory
                            sys_wr_en   <= 1'b1;
                            sys_wr_addr <= dma_sys_addr_reg + wr_cnt;
                            sys_wr_data <= dma_sram_rd_data;
                        end
                    end else begin
                        dma_sram_wr_en <= 1'b0;
                        sys_wr_en      <= 1'b0;
                    end

                    // Check for transfer termination
                    if (wr_cnt == dma_len_reg && !active_pipe_d1) begin
                        dma_busy <= 1'b0;
                        dma_done <= 1'b1;
                        state    <= DMA_STATE_IDLE;
                    end
                end
            endcase
        end
    end

endmodule
