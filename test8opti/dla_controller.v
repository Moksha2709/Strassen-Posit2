// =============================================================================
// dla_controller.v — Verilog
// Upgraded DLA controller supporting OP_MATMUL and OP_VADD slot execution
// Configured for 192-bit widths (triple-packed formats)
// =============================================================================

module dla_controller (
    input  wire                             clk,
    input  wire                             resetn,

    // Instruction Interface
    input  wire [1:0]                       inst_op,         // 00: NOP, 01: MATMUL, 10: VADD
    input  wire                             inst_use_act,    // Fused activation flag (ReLU)
    input  wire                             inst_vadd_init,  // Force second operand (accumulator input) to zero
    input  wire [1:0]                       inst_weight_slot,// Selected Weight slot (or second source slot for VADD)
    input  wire [1:0]                       inst_act_slot,   // Selected Input Activation slot (0 to 3)
    input  wire [1:0]                       inst_dest_slot,  // Selected Output Destination slot (0 to 3)
    input  wire                             inst_val,        // Instruction valid
    output reg                              inst_rdy,        // Controller ready for new instruction

    // Controller outputs
    output reg                              dla_done,        // High for 1 cycle when instruction finishes
    output reg                              act_enable,      // Controls whether ReLU is applied to stream
    output reg                              vadd_enable,     // High during OP_VADD computation
    output wire                             vadd_init,       // Active during OP_VADD to force zero on second operand

    // Weight SRAM Read Interface (Port B)
    output reg                              weight_rd_en,
    output reg [6:0]                        weight_rd_addr,
    input  wire [191:0]                     weight_rd_data,

    // Activation SRAM Port A Read Interface (reused during OP_VADD)
    output reg                              act_rd_en_a,
    output reg [6:0]                        act_rd_addr_a,

    // Activation SRAM Port B Interface
    output reg                              act_rd_en,
    output reg [6:0]                        act_rd_addr,
    input  wire [191:0]                     act_rd_data,
    output wire                             act_wr_en,
    output wire [6:0]                       act_wr_addr,

    // Interface to Strassen Matrix Engine
    output reg                              matmul_start,
    input  wire                             matmul_done,
    output wire                             input_a_val,
    output wire [191:0]                     input_a_data,
    input  wire                             input_a_rdy,
    output wire                             input_b_val,
    output wire [191:0]                     input_b_data,
    input  wire                             input_b_rdy,

    // Write-back streaming indicators
    input  wire                             out_val,
    input  wire                             out_rdy
);

    // Opcodes
    localparam [1:0]
        OP_NOP    = 2'b00,
        OP_MATMUL = 2'b01,
        OP_VADD   = 2'b10;

    // FSM States
    localparam [1:0]
        STATE_IDLE   = 2'd0,
        STATE_START  = 2'd1,
        STATE_WAIT   = 2'd2,
        STATE_DONE   = 2'd3;

    reg [1:0] state;
    reg       use_act_reg;
    reg       vadd_init_reg;
    reg [1:0] inst_op_reg;
    reg [1:0] weight_slot_reg;
    reg [1:0] act_slot_reg;
    reg [1:0] dest_slot_reg;

    // Counters for SRAM address sequencing
    reg [5:0] read_cnt;
    reg       sram_rd_valid;
    reg [5:0] write_cnt;

    // 5-cycle pipeline delay shift register for vector addition
    reg [4:0] vadd_val_pipe;

    // FSM execution logic
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            state           <= STATE_IDLE;
            inst_rdy        <= 1'b1;
            dla_done        <= 1'b0;
            act_enable      <= 1'b0;
            vadd_enable     <= 1'b0;
            matmul_start    <= 1'b0;
            use_act_reg     <= 1'b0;
            vadd_init_reg   <= 1'b0;
            inst_op_reg     <= 2'd0;
            weight_slot_reg <= 2'd0;
            act_slot_reg    <= 2'd0;
            dest_slot_reg   <= 2'd0;
        end else begin
            dla_done     <= 1'b0;
            matmul_start <= 1'b0;

            case (state)
                STATE_IDLE: begin
                    inst_rdy    <= 1'b1;
                    vadd_enable <= 1'b0;
                    if (inst_val && inst_rdy) begin
                        inst_rdy        <= 1'b0;
                        use_act_reg     <= inst_use_act;
                        vadd_init_reg   <= inst_vadd_init;
                        inst_op_reg     <= inst_op;
                        weight_slot_reg <= inst_weight_slot;
                        act_slot_reg    <= inst_act_slot;
                        dest_slot_reg   <= inst_dest_slot;

                        if (inst_op == OP_MATMUL || inst_op == OP_VADD) begin
                            state <= STATE_START;
                        end else begin
                            state <= STATE_DONE;
                        end
                    end
                end

                STATE_START: begin
                    if (inst_op_reg == OP_MATMUL) begin
                        matmul_start <= 1'b1;
                    end else if (inst_op_reg == OP_VADD) begin
                        vadd_enable  <= 1'b1;
                    end
                    act_enable <= use_act_reg;
                    state      <= STATE_WAIT;
                end

                STATE_WAIT: begin
                    if (inst_op_reg == OP_MATMUL) begin
                        if (matmul_done) begin
                            state <= STATE_DONE;
                        end
                    end else if (inst_op_reg == OP_VADD) begin
                        if (write_cnt == 6'd32) begin
                            state <= STATE_DONE;
                        end
                    end else begin
                        state <= STATE_DONE;
                    end
                end

                STATE_DONE: begin
                    dla_done    <= 1'b1;
                    act_enable  <= 1'b0;
                    vadd_enable <= 1'b0;
                    state       <= STATE_IDLE;
                end

                default: state <= STATE_IDLE;
            endcase
        end
    end

    // SRAM Read sequencing (loading into compute engines)
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            read_cnt       <= 6'd0;
            weight_rd_en   <= 1'b0;
            weight_rd_addr <= 7'd0;
            act_rd_en_a    <= 1'b0;
            act_rd_addr_a  <= 7'd0;
            act_rd_en      <= 1'b0;
            act_rd_addr    <= 7'd0;
            sram_rd_valid  <= 1'b0;
        end else begin
            if (state == STATE_WAIT) begin
                if (inst_op_reg == OP_MATMUL) begin
                    // MatMul mode: weight SRAM is loaded into B, act SRAM Port B into A
                    if (input_a_rdy && read_cnt < 6'd32) begin
                        weight_rd_en   <= 1'b1;
                        weight_rd_addr <= {weight_slot_reg, read_cnt[4:0]};
                        act_rd_en      <= 1'b1;
                        act_rd_addr    <= {act_slot_reg, read_cnt[4:0]};
                        read_cnt       <= read_cnt + 6'd1;
                    end else begin
                        weight_rd_en   <= 1'b0;
                        act_rd_en      <= 1'b0;
                    end
                    sram_rd_valid <= weight_rd_en;

                end else if (inst_op_reg == OP_VADD) begin
                    // VADD mode: act SRAM Port A reads Operand 2 (from weight_slot_reg)
                    // act SRAM Port B reads Operand 1 (from act_slot_reg)
                    if (read_cnt < 6'd32) begin
                        act_rd_en_a    <= 1'b1;
                        act_rd_addr_a  <= {weight_slot_reg, read_cnt[4:0]};
                        act_rd_en      <= 1'b1;
                        act_rd_addr    <= {act_slot_reg, read_cnt[4:0]};
                        read_cnt       <= read_cnt + 6'd1;
                    end else begin
                        act_rd_en_a    <= 1'b0;
                        act_rd_en      <= 1'b0;
                    end
                end
            end else begin
                read_cnt       <= 6'd0;
                weight_rd_en   <= 1'b0;
                weight_rd_addr <= 7'd0;
                act_rd_en_a    <= 1'b0;
                act_rd_addr_a  <= 7'd0;
                act_rd_en      <= 1'b0;
                act_rd_addr    <= 7'd0;
                sram_rd_valid  <= 1'b0;
            end
        end
    end

    // Pipeline delay shift register to handle 4-cycle posit addition delay + 1-cycle SRAM read latency
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            vadd_val_pipe <= 5'b0;
        end else begin
            if (state == STATE_WAIT && inst_op_reg == OP_VADD) begin
                vadd_val_pipe <= {vadd_val_pipe[3:0], (read_cnt > 6'd0 && read_cnt <= 6'd32 && act_rd_en)};
            end else begin
                vadd_val_pipe <= 5'b0;
            end
        end
    end

    // SRAM Write sequencing (storing outputs)
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            write_cnt <= 6'd0;
        end else begin
            if (state == STATE_WAIT) begin
                if (inst_op_reg == OP_MATMUL && out_val && out_rdy) begin
                    write_cnt <= write_cnt + 6'd1;
                end else if (inst_op_reg == OP_VADD && vadd_val_pipe[4]) begin
                    write_cnt <= write_cnt + 6'd1;
                end
            end else begin
                write_cnt <= 6'd0;
            end
        end
    end

    assign act_wr_en   = (state == STATE_WAIT) ? 
                         ((inst_op_reg == OP_MATMUL) ? (out_val && out_rdy) : vadd_val_pipe[4]) : 
                         1'b0;
    assign act_wr_addr = {dest_slot_reg, write_cnt[4:0]};

    // Connect DLA inputs/SRAM streams to the Matrix Engine
    assign input_a_val  = (inst_op_reg == OP_MATMUL) ? sram_rd_valid : 1'b0;
    assign input_b_val  = (inst_op_reg == OP_MATMUL) ? sram_rd_valid : 1'b0;
    assign input_a_data = act_rd_data;
    assign input_b_data = weight_rd_data;
    assign vadd_init    = vadd_init_reg;

    always @(posedge clk) begin
        if (state == STATE_WAIT && inst_op_reg == OP_VADD) begin
            $display("[DLA CONTROLLER VADD] Time=%0d ns, read_cnt=%d, write_cnt=%d, pipe=%b, act_rd_en=%b", $time, read_cnt, write_cnt, vadd_val_pipe, act_rd_en);
        end
    end

endmodule
