// =============================================================================
// dla_top.v — Verilog
// Upgraded DLA wrapper with 3-port Weight and Activation SRAM buffers
// Configured for 8-bit triple-packed / 4-bit 6-way SIMD architecture
// =============================================================================
`include "posit_pkg.vh"
`include "strassen_pkg.vh"

module dla_top #(
    parameter SZI         = `DEFAULT_SZI,
    parameter SZJ         = `DEFAULT_SZJ,
    parameter POSIT_WIDTH = `POSIT_WIDTH,
    parameter POSIT_ES    = `POSIT_ES
) (
    input  wire                             clk,
    input  wire                             resetn,
    input  wire                             simd_mode, // 0 = 3x 8-bit, 1 = 6x 4-bit SIMD

    // Instruction Interface
    input  wire [1:0]                       inst_op,
    input  wire                             inst_use_act,
    input  wire                             inst_vadd_init,
    input  wire [1:0]                       inst_weight_slot,
    input  wire [1:0]                       inst_act_slot,
    input  wire [1:0]                       inst_dest_slot,
    input  wire                             inst_val,
    output wire                             inst_rdy,
    output wire                             dla_done,

    // Sideband Weight Buffer Loader (Port A)
    input  wire                             weight_wr_en,
    input  wire [6:0]                       weight_wr_addr,
    input  wire [191:0]                     weight_wr_data,

    // Sideband Activation Buffer Loader/Reader (Port A)
    input  wire                             act_wr_en,
    input  wire [6:0]                       act_wr_addr,
    input  wire [191:0]                     act_wr_data,
    input  wire                             act_rd_en,
    input  wire [6:0]                       act_rd_addr,
    output wire [191:0]                     act_rd_data,

    // Optional direct external streaming outputs
    output wire                             out_val,
    output wire [SZJ*POSIT_WIDTH*3-1:0]     out_data,
    input  wire                             out_rdy
);

    localparam PW = POSIT_WIDTH;

    // --- SRAM read/write lines connected to the controller ---
    wire         weight_rd_en_b;
    wire [6:0]   weight_rd_addr_b;
    wire [191:0] weight_rd_data_b;

    wire         act_rd_en_a_b;
    wire [6:0]   act_rd_addr_a_b;

    wire         act_rd_en_b;
    wire [6:0]   act_rd_addr_b;
    wire [191:0] act_rd_data_b;

    wire         act_wr_en_b;
    wire [6:0]   act_wr_addr_b;
    wire [191:0] act_wr_data_b;

    // --- Handshake stream wires between SRAM / Controller / Engine ---
    wire         engine_input_a_val;
    wire [191:0] engine_input_a_data;
    wire         engine_input_a_rdy;

    wire         engine_input_b_val;
    wire [191:0] engine_input_b_data;
    wire         engine_input_b_rdy;

    wire         engine_out_val;
    wire [191:0] engine_out_data;
    wire [191:0] post_act_out_data;

    wire         matmul_start;
    wire         matmul_done;
    wire         act_enable;
    wire         vadd_enable;

    // Output from the Vector Addition Unit
    wire [191:0] vadd_out_data;

    assign       act_wr_data_b   = post_act_out_data;

    // --- Instantiate 3-Port Weight SRAM Buffer ---
    dla_sram #(
        .WIDTH(192),
        .DEPTH(128)
    ) weight_buffer (
        .clk(clk),
        .wr_en_a(weight_wr_en),
        .addr_a(weight_wr_addr),
        .data_in_a(weight_wr_data),
        .data_out_a(),                 // Port A is write-only for weights
        .wr_en_b(1'b0),                // Port B is unused
        .addr_b(7'd0),
        .data_in_b(192'd0),
        .rd_en_c(weight_rd_en_b),      // Port C reads weight coefficients
        .addr_c(weight_rd_addr_b),
        .data_out_c(weight_rd_data_b)
    );

    // Mux Port A address of Activation Buffer to support readback and VADD second read operand
    wire [6:0]   act_sram_addr_a = (act_wr_en) ? act_wr_addr : ((vadd_enable) ? act_rd_addr_a_b : act_rd_addr);

    // --- Instantiate 3-Port Activation SRAM Buffer ---
    dla_sram #(
        .WIDTH(192),
        .DEPTH(128)
    ) activation_buffer (
        .clk(clk),
        .wr_en_a(act_wr_en),
        .addr_a(act_sram_addr_a),
        .data_in_a(act_wr_data),
        .data_out_a(act_rd_data),      // Port A used for sideband read or VADD Operand 2
        .wr_en_b(act_wr_en_b),          // Port B handles DLA execution outputs
        .addr_b(act_wr_addr_b),
        .data_in_b(act_wr_data_b),
        .rd_en_c(act_rd_en_b),          // Port C handles DLA Operand 1 reads
        .addr_c(act_rd_addr_b),
        .data_out_c(act_rd_data_b)
    );

    wire         vadd_init;

    // --- Instantiate Upgraded DLA Controller ---
    dla_controller controller_inst (
        .clk(clk),
        .resetn(resetn),
        .inst_op(inst_op),
        .inst_use_act(inst_use_act),
        .inst_vadd_init(inst_vadd_init),
        .inst_weight_slot(inst_weight_slot),
        .inst_act_slot(inst_act_slot),
        .inst_dest_slot(inst_dest_slot),
        .inst_val(inst_val),
        .inst_rdy(inst_rdy),
        .dla_done(dla_done),
        .act_enable(act_enable),
        .vadd_enable(vadd_enable),
        .vadd_init(vadd_init),
        .weight_rd_en(weight_rd_en_b),
        .weight_rd_addr(weight_rd_addr_b),
        .weight_rd_data(weight_rd_data_b),
        .act_rd_en_a(act_rd_en_a_b),
        .act_rd_addr_a(act_rd_addr_a_b),
        .act_rd_en(act_rd_en_b),
        .act_rd_addr(act_rd_addr_b),
        .act_rd_data(act_rd_data_b),
        .act_wr_en(act_wr_en_b),
        .act_wr_addr(act_wr_addr_b),
        .matmul_start(matmul_start),
        .matmul_done(matmul_done),
        .input_a_val(engine_input_a_val),
        .input_a_data(engine_input_a_data),
        .input_a_rdy(engine_input_a_rdy),
        .input_b_val(engine_input_b_val),
        .input_b_data(engine_input_b_data),
        .input_b_rdy(engine_input_b_rdy),
        .out_val(engine_out_val),
        .out_rdy(out_rdy)
    );

    // Raw unpadded ports for internal arithmetic engines
    wire [SZJ*PW*3-1:0] engine_out_data_raw;
    wire [SZJ*PW*3-1:0] vadd_out_data_raw;
    wire [SZJ*PW*3-1:0] post_act_out_data_raw;

    // --- Instantiate Strassen Matrix Multiplication Engine ---
    strassen_top #(
        .SZI(SZI),
        .SZJ(SZJ),
        .POSIT_WIDTH(PW),
        .POSIT_ES(POSIT_ES)
    ) matrix_engine (
        .clk(clk),
        .resetn(resetn),
        .start(matmul_start),
        .done(matmul_done),
        .input_a_val(engine_input_a_val),
        .input_a_data(engine_input_a_data[SZJ*PW*3-1:0]),
        .input_a_rdy(engine_input_a_rdy),
        .input_b_val(engine_input_b_val),
        .input_b_data(engine_input_b_data[SZJ*PW*3-1:0]),
        .input_b_rdy(engine_input_b_rdy),
        .out_val(engine_out_val),
        .out_data(engine_out_data_raw),
        .out_rdy(out_rdy)
    );

    assign engine_out_data = {{(192 - SZJ*PW*3){1'b0}}, engine_out_data_raw};

    wire [SZJ*PW*3-1:0] vadd_in_b = (vadd_init) ? {SZJ*PW*3{1'b0}} : act_rd_data_b[SZJ*PW*3-1:0];

    // --- Instantiate Vector Addition Unit ---
    vector_add #(
        .SZJ(SZJ),
        .POSIT_WIDTH(PW*3),
        .POSIT_ES(POSIT_ES)
    ) vector_add_unit (
        .clk(clk),
        .resetn(resetn),
        .simd_mode(simd_mode),
        .in_a(act_rd_data[SZJ*PW*3-1:0]),   // Operand 2 (from Port A)
        .in_b(vadd_in_b),                 // Operand 1 (from Port C or Zero)
        .out(vadd_out_data_raw)
    );

    assign vadd_out_data = {{(192 - SZJ*PW*3){1'b0}}, vadd_out_data_raw};

    // Fused activation input muxing (select between VADD output and MatMul engine output)
    wire [191:0] act_unit_in = (vadd_enable) ? vadd_out_data : engine_out_data;

    // --- Instantiate Vector Activation Unit (ReLU) ---
    vector_activation #(
        .SZJ(SZJ),
        .POSIT_WIDTH(PW*3)
    ) activation_unit (
        .enable(act_enable),
        .simd_mode(simd_mode),
        .in_data(act_unit_in[SZJ*PW*3-1:0]),
        .out_data(post_act_out_data_raw)
    );

    assign post_act_out_data = {{(192 - SZJ*PW*3){1'b0}}, post_act_out_data_raw};

    // Expose outputs externally for verification observation
    assign out_val  = (vadd_enable) ? act_wr_en_b : engine_out_val;
    assign out_data = post_act_out_data;
endmodule
