// =============================================================================
// dla_axi_wrapper.v — Verilog
// AXI-Lite registers and DMA control interface for DLA system integration
// Configured for 192-bit SRAM widths (triple-packed formats)
// =============================================================================
`include "posit_pkg.vh"

module dla_axi_wrapper #(
    parameter SZI         = `DEFAULT_SZI,
    parameter SZJ         = `DEFAULT_SZJ,
    parameter POSIT_WIDTH = `POSIT_WIDTH,
    parameter POSIT_ES    = `POSIT_ES
) (
    input  wire                             s_axi_aclk,
    input  wire                             s_axi_aresetn,

    // AXI Write Address Channel
    input  wire [5:0]                       s_axi_awaddr,
    input  wire                             s_axi_awvalid,
    output reg                              s_axi_awready,

    // AXI Write Data Channel
    input  wire [31:0]                      s_axi_wdata,
    input  wire                             s_axi_wvalid,
    output reg                              s_axi_wready,

    // AXI Write Response Channel
    output reg  [1:0]                       s_axi_bresp,
    output reg                              s_axi_bvalid,
    input  wire                             s_axi_bready,

    // AXI Read Address Channel
    input  wire [5:0]                       s_axi_araddr,
    input  wire                             s_axi_arvalid,
    output reg                              s_axi_arready,

    // AXI Read Data Channel
    output reg  [31:0]                      s_axi_rdata,
    output reg  [1:0]                       s_axi_rresp,
    output reg                              s_axi_rvalid,
    input  wire                             s_axi_rready,

    // Master DRAM Memory Port Interface
    output wire                             dram_rd_en,
    output wire [31:0]                      dram_rd_addr,
    input  wire [191:0]                     dram_rd_data,

    output wire                             dram_wr_en,
    output wire [31:0]                      dram_wr_addr,
    output wire [191:0]                     dram_wr_data
);

    // Register Map offsets
    localparam [5:0]
        REG_CTRL         = 6'h00, // [0]: Start, [1]: SIMD Mode, [8]: Ready, [9]: Done
        REG_INST_OP      = 6'h04, // [1:0]: Opcode, [8]: Use ReLU, [9]: Accumulator init
        REG_INST_SLOTS   = 6'h08, // [1:0]: Weight slot, [3:2]: Act slot, [5:4]: Dest slot
        REG_SRAM_ADDR    = 6'h0C, // [6:0]: Row addr, [7]: Sel (0: Act, 1: Weight)
        REG_SRAM_DATA_0  = 6'h10, // Data bits [31:0]
        REG_SRAM_DATA_1  = 6'h14, // Data bits [63:32]
        REG_SRAM_DATA_2  = 6'h18, // Data bits [95:64]
        REG_SRAM_DATA_3  = 6'h1C, // Data bits [127:96]
        REG_SRAM_DATA_4  = 6'h30, // Data bits [159:128]
        REG_SRAM_DATA_5  = 6'h34, // Data bits [191:160] (Triggers write transaction)
        REG_DMA_SYS_ADDR = 6'h20, // Base System DRAM Address
        REG_DMA_SRAM_ADDR= 6'h24, // Target SRAM destination (Bit 7: Sel)
        REG_DMA_LEN      = 6'h28, // Number of rows to transfer
        REG_DMA_CTRL     = 6'h2C; // DMA control (Bit 0: Start, Bit 1: Dir, Bit 8: Busy, Bit 9: Done)

    // Hardware internal registers
    reg [31:0] reg_ctrl;
    reg [31:0] reg_inst_op;
    reg [31:0] reg_inst_slots;
    reg [31:0] reg_sram_addr;
    reg [31:0] reg_sram_data_0;
    reg [31:0] reg_sram_data_1;
    reg [31:0] reg_sram_data_2;
    reg [31:0] reg_sram_data_3;
    reg [31:0] reg_sram_data_4;
    reg [31:0] reg_sram_data_5;

    reg [31:0] reg_dma_sys_addr;
    reg [31:0] reg_dma_sram_addr;
    reg [31:0] reg_dma_len;
    reg [31:0] reg_dma_ctrl;

    // DLA signals
    wire [1:0]  inst_op         = reg_inst_op[1:0];
    wire        inst_use_act    = reg_inst_op[8];
    wire        inst_vadd_init  = reg_inst_op[9];
    wire [1:0]  inst_weight_slot= reg_inst_slots[1:0];
    wire [1:0]  inst_act_slot   = reg_inst_slots[3:2];
    wire [1:0]  inst_dest_slot  = reg_inst_slots[5:4];
    reg         inst_val;
    wire        inst_rdy;
    wire        dla_done;

    // CPU SRAM direct write/read signals
    reg         weight_wr_en_cpu;
    wire [6:0]  weight_wr_addr_cpu = reg_sram_addr[6:0];
    wire [191:0] weight_wr_data_cpu = {s_axi_wdata, reg_sram_data_4, reg_sram_data_3, reg_sram_data_2, reg_sram_data_1, reg_sram_data_0};

    reg         act_wr_en_cpu;
    wire [6:0]  act_wr_addr_cpu    = reg_sram_addr[6:0];
    wire [191:0] act_wr_data_cpu   = {s_axi_wdata, reg_sram_data_4, reg_sram_data_3, reg_sram_data_2, reg_sram_data_1, reg_sram_data_0};
    reg         act_rd_en_cpu;
    wire [6:0]  act_rd_addr_cpu    = reg_sram_addr[6:0];
    wire [191:0] act_rd_data;

    wire        sram_sel_cpu       = reg_sram_addr[7];

    // DMA Controller Interface signals
    reg         dma_start;
    wire        dma_busy;
    wire        dma_done;

    wire         dma_sram_wr_en;
    wire [6:0]   dma_sram_addr_val;
    wire [191:0] dma_sram_wr_data;
    wire         dma_sram_rd_en;
    wire         dma_sram_sel;

    // Multiplexed SRAM Port A signals (CPU manual registers vs. DMA)
    wire         final_weight_wr_en   = (dma_busy) ? (dma_sram_sel ? dma_sram_wr_en : 1'b0) : weight_wr_en_cpu;
    wire [6:0]   final_weight_wr_addr = (dma_busy) ? dma_sram_addr_val : weight_wr_addr_cpu;
    wire [191:0] final_weight_wr_data = (dma_busy) ? dma_sram_wr_data : weight_wr_data_cpu;

    wire         final_act_wr_en      = (dma_busy) ? (!dma_sram_sel ? dma_sram_wr_en : 1'b0) : act_wr_en_cpu;
    wire [6:0]   final_act_wr_addr    = (dma_busy) ? dma_sram_addr_val : act_wr_addr_cpu;
    wire [191:0] final_act_wr_data    = (dma_busy) ? dma_sram_wr_data : act_wr_data_cpu;

    wire         final_act_rd_en      = (dma_busy) ? (!dma_sram_sel ? dma_sram_rd_en : 1'b0) : act_rd_en_cpu;
    wire [6:0]   final_act_rd_addr    = (dma_busy) ? dma_sram_addr_val : act_rd_addr_cpu;

    // FSM States for write channel
    localparam [1:0]
        WSTATE_IDLE = 2'd0,
        WSTATE_DATA = 2'd1,
        WSTATE_RESP = 2'd2;

    reg [1:0] wstate;
    reg [5:0] waddr;

    // AXI Write FSM
    always @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if (!s_axi_aresetn) begin
            wstate            <= WSTATE_IDLE;
            s_axi_awready     <= 1'b0;
            s_axi_wready      <= 1'b0;
            s_axi_bvalid      <= 1'b0;
            s_axi_bresp       <= 2'b00;
            waddr             <= 6'h00;
            reg_ctrl          <= 32'd0;
            reg_inst_op       <= 32'd0;
            reg_inst_slots    <= 32'd0;
            reg_sram_addr     <= 32'd0;
            reg_sram_data_0   <= 32'd0;
            reg_sram_data_1   <= 32'd0;
            reg_sram_data_2   <= 32'd0;
            reg_sram_data_3   <= 32'd0;
            reg_sram_data_4   <= 32'd0;
            reg_sram_data_5   <= 32'd0;
            reg_dma_sys_addr  <= 32'd0;
            reg_dma_sram_addr <= 32'd0;
            reg_dma_len       <= 32'd0;
            reg_dma_ctrl      <= 32'd0;
            inst_val          <= 1'b0;
            weight_wr_en_cpu  <= 1'b0;
            act_wr_en_cpu     <= 1'b0;
            dma_start         <= 1'b0;
        end else begin
            inst_val          <= 1'b0;
            weight_wr_en_cpu  <= 1'b0;
            act_wr_en_cpu     <= 1'b0;
            dma_start         <= 1'b0;

            // Handshake registers back to CPU observation
            reg_ctrl[8]       <= inst_rdy;
            if (dla_done) reg_ctrl[9] <= 1'b1;
            reg_dma_ctrl[8]   <= dma_busy;
            if (dma_done) reg_dma_ctrl[9] <= 1'b1;

            case (wstate)
                WSTATE_IDLE: begin
                    s_axi_awready <= 1'b1;
                    s_axi_bvalid  <= 1'b0;
                    if (s_axi_awvalid && s_axi_awready) begin
                        s_axi_awready <= 1'b0;
                        waddr         <= s_axi_awaddr;
                        s_axi_wready  <= 1'b1;
                        wstate        <= WSTATE_DATA;
                    end
                end

                WSTATE_DATA: begin
                    if (s_axi_wvalid && s_axi_wready) begin
                        s_axi_wready <= 1'b0;
                        case (waddr)
                            REG_CTRL: begin
                                reg_ctrl[0] <= s_axi_wdata[0];
                                reg_ctrl[1] <= s_axi_wdata[1];
                                if (s_axi_wdata[0]) begin
                                    inst_val    <= 1'b1;
                                    reg_ctrl[9] <= 1'b0;
                                end
                            end
                            REG_INST_OP:    reg_inst_op    <= s_axi_wdata;
                            REG_INST_SLOTS: reg_inst_slots <= s_axi_wdata;
                            REG_SRAM_ADDR:  reg_sram_addr  <= s_axi_wdata;
                            REG_SRAM_DATA_0:reg_sram_data_0<= s_axi_wdata;
                            REG_SRAM_DATA_1:reg_sram_data_1<= s_axi_wdata;
                            REG_SRAM_DATA_2:reg_sram_data_2<= s_axi_wdata;
                            REG_SRAM_DATA_3:reg_sram_data_3<= s_axi_wdata;
                            REG_SRAM_DATA_4:reg_sram_data_4<= s_axi_wdata;
                            REG_SRAM_DATA_5:begin
                                reg_sram_data_5 <= s_axi_wdata;
                                if (sram_sel_cpu) begin
                                    weight_wr_en_cpu <= 1'b1;
                                end else begin
                                    act_wr_en_cpu    <= 1'b1;
                                end
                            end
                            REG_DMA_SYS_ADDR: reg_dma_sys_addr  <= s_axi_wdata;
                            REG_DMA_SRAM_ADDR:reg_dma_sram_addr <= s_axi_wdata;
                            REG_DMA_LEN:      reg_dma_len       <= s_axi_wdata;
                            REG_DMA_CTRL: begin
                                reg_dma_ctrl[1:0] <= s_axi_wdata[1:0];
                                if (s_axi_wdata[0]) begin
                                    dma_start        <= 1'b1;
                                    reg_dma_ctrl[9]  <= 1'b0;
                                end
                            end
                        endcase
                        s_axi_bvalid <= 1'b1;
                        wstate       <= WSTATE_RESP;
                    end
                end

                WSTATE_RESP: begin
                    s_axi_bvalid <= 1'b1;
                    if (s_axi_bvalid && s_axi_bready) begin
                        s_axi_bvalid <= 1'b0;
                        wstate       <= WSTATE_IDLE;
                    end
                end
            endcase
        end
    end

    // Automatic Port A read trigger upon updating REG_SRAM_ADDR by CPU
    reg act_rd_pipe_val;
    always @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if (!s_axi_aresetn) begin
            act_rd_en_cpu   <= 1'b0;
            act_rd_pipe_val <= 1'b0;
            reg_sram_data_0 <= 32'd0;
            reg_sram_data_1 <= 32'd0;
            reg_sram_data_2 <= 32'd0;
            reg_sram_data_3 <= 32'd0;
            reg_sram_data_4 <= 32'd0;
            reg_sram_data_5 <= 32'd0;
        end else begin
            if (wstate == WSTATE_RESP && waddr == REG_SRAM_ADDR && !reg_sram_addr[7] && !dma_busy) begin
                act_rd_en_cpu   <= 1'b1;
                act_rd_pipe_val <= 1'b1;
            end else begin
                act_rd_en_cpu   <= 1'b0;
                act_rd_pipe_val <= 1'b0;
            end

            if (act_rd_pipe_val) begin
                reg_sram_data_0 <= act_rd_data[31:0];
                reg_sram_data_1 <= act_rd_data[63:32];
                reg_sram_data_2 <= act_rd_data[95:64];
                reg_sram_data_3 <= act_rd_data[127:96];
                reg_sram_data_4 <= act_rd_data[159:128];
                reg_sram_data_5 <= act_rd_data[191:160];
            end
        end
    end

    // FSM States for read channel
    localparam [0:0]
        RSTATE_IDLE = 1'b0,
        RSTATE_DATA = 1'b1;

    reg rstate;

    // AXI Read FSM
    always @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if (!s_axi_aresetn) begin
            rstate        <= RSTATE_IDLE;
            s_axi_arready <= 1'b0;
            s_axi_rvalid  <= 1'b0;
            s_axi_rdata   <= 32'd0;
            s_axi_rresp   <= 2'b00;
        end else begin
            case (rstate)
                RSTATE_IDLE: begin
                    s_axi_arready <= 1'b1;
                    s_axi_rvalid  <= 1'b0;
                    if (s_axi_arvalid && s_axi_arready) begin
                        s_axi_arready <= 1'b0;
                        s_axi_rvalid  <= 1'b1;
                        case (s_axi_araddr)
                            REG_CTRL:          s_axi_rdata <= reg_ctrl;
                            REG_INST_OP:       s_axi_rdata <= reg_inst_op;
                            REG_INST_SLOTS:    s_axi_rdata <= reg_inst_slots;
                            REG_SRAM_ADDR:     s_axi_rdata <= reg_sram_addr;
                            REG_SRAM_DATA_0:   s_axi_rdata <= reg_sram_data_0;
                            REG_SRAM_DATA_1:   s_axi_rdata <= reg_sram_data_1;
                            REG_SRAM_DATA_2:   s_axi_rdata <= reg_sram_data_2;
                            REG_SRAM_DATA_3:   s_axi_rdata <= reg_sram_data_3;
                            REG_SRAM_DATA_4:   s_axi_rdata <= reg_sram_data_4;
                            REG_SRAM_DATA_5:   s_axi_rdata <= reg_sram_data_5;
                            REG_DMA_SYS_ADDR:  s_axi_rdata <= reg_dma_sys_addr;
                            REG_DMA_SRAM_ADDR: s_axi_rdata <= reg_dma_sram_addr;
                            REG_DMA_LEN:       s_axi_rdata <= reg_dma_len;
                            REG_DMA_CTRL:      s_axi_rdata <= reg_dma_ctrl;
                            default:           s_axi_rdata <= 32'hDEADBEEF;
                        endcase
                        rstate <= RSTATE_DATA;
                    end
                end

                RSTATE_DATA: begin
                    if (s_axi_rvalid && s_axi_rready) begin
                        s_axi_rvalid <= 1'b0;
                        rstate       <= RSTATE_IDLE;
                    end
                end
            endcase
        end
    end

    // --- Instantiate DMA Controller Module ---
    dla_dma_controller dma_engine (
        .clk(s_axi_aclk),
        .resetn(s_axi_aresetn),
        .dma_sys_addr(reg_dma_sys_addr),
        .dma_sram_addr(reg_dma_sram_addr[7:0]),
        .dma_len(reg_dma_len[5:0]),
        .dma_start(dma_start),
        .dma_dir(reg_dma_ctrl[1]),
        .dma_busy(dma_busy),
        .dma_done(dma_done),
        .sys_rd_en(dram_rd_en),
        .sys_rd_addr(dram_rd_addr),
        .sys_rd_data(dram_rd_data),
        .sys_wr_en(dram_wr_en),
        .sys_wr_addr(dram_wr_addr),
        .sys_wr_data(dram_wr_data),
        .dma_sram_wr_en(dma_sram_wr_en),
        .dma_sram_addr_val(dma_sram_addr_val),
        .dma_sram_wr_data(dma_sram_wr_data),
        .dma_sram_rd_en(dma_sram_rd_en),
        .dma_sram_rd_data(act_rd_data),
        .dma_sram_sel(dma_sram_sel)
    );

    // --- Instantiate the DLA Top Module ---
    dla_top #(
        .SZI(SZI),
        .SZJ(SZJ),
        .POSIT_WIDTH(POSIT_WIDTH),
        .POSIT_ES(POSIT_ES)
    ) dla_core (
        .clk(s_axi_aclk),
        .resetn(s_axi_aresetn),
        .inst_op(inst_op),
        .inst_use_act(inst_use_act),
        .inst_vadd_init(inst_vadd_init),
        .inst_weight_slot(inst_weight_slot),
        .inst_act_slot(inst_act_slot),
        .inst_dest_slot(inst_dest_slot),
        .inst_val(inst_val),
        .inst_rdy(inst_rdy),
        .dla_done(dla_done),
        .weight_wr_en(final_weight_wr_en),
        .weight_wr_addr(final_weight_wr_addr),
        .weight_wr_data(final_weight_wr_data),
        .act_wr_en(final_act_wr_en),
        .act_wr_addr(final_act_wr_addr),
        .act_wr_data(final_act_wr_data),
        .act_rd_en(final_act_rd_en),
        .act_rd_addr(final_act_rd_addr),
        .act_rd_data(act_rd_data),
        .out_val(),
        .out_data(),
        .out_rdy(1'b1)
    );

    always @(posedge s_axi_aclk) begin
        if (s_axi_awvalid && s_axi_awready) begin
            $display("[AXI WRITE ADDR] Address=%h at Time=%0d ns", s_axi_awaddr, $time);
        end
        if (s_axi_wvalid && s_axi_wready) begin
            $display("[AXI WRITE DATA] Data=%h at Time=%0d ns", s_axi_wdata, $time);
        end
        if (s_axi_arvalid && s_axi_arready) begin
            $display("[AXI READ REQ] Address=%h at Time=%0d ns", s_axi_araddr, $time);
        end
        if (s_axi_rvalid && s_axi_rready) begin
            $display("[AXI READ DATA] Data=%h at Time=%0d ns", s_axi_rdata, $time);
        end
    end

endmodule
