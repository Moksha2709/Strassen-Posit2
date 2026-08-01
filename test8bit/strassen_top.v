// =============================================================================
// strassen_top.v — Verilog
// Parallel Multisystolic Accelerator Top-Level with Triple-Packed Posit MACs
// Computes three parallel 8-bit matrix multiplications concurrently per tile.
// Optimized 48-bit bus interconnect footprint.
// =============================================================================
`include "posit_pkg.vh"
`include "strassen_pkg.vh"

module strassen_top #(
    parameter SZI         = `DEFAULT_SZI,
    parameter SZJ         = `DEFAULT_SZJ,
    parameter POSIT_WIDTH = `POSIT_WIDTH,
    parameter POSIT_ES    = `POSIT_ES
) (
    input  wire                             clk,
    input  wire                             resetn,

    // Execution control
    input  wire                             start,
    output wire                             done,

    // Input Matrix A (Streaming, 3x 8-bit packed = 24 bits per element)
    input  wire                             input_a_val,
    input  wire [SZJ*POSIT_WIDTH*3-1:0]     input_a_data,
    output wire                             input_a_rdy,

    // Input Matrix B (Streaming, 3x 8-bit packed = 24 bits per element)
    input  wire                             input_b_val,
    input  wire [SZJ*POSIT_WIDTH*3-1:0]     input_b_data,
    output wire                             input_b_rdy,

    // Output Matrix C (Streaming, 3x 8-bit packed = 24 bits per element)
    output wire                             out_val,
    output wire [SZJ*POSIT_WIDTH*3-1:0]     out_data,
    input  wire                             out_rdy
);

    localparam PW = POSIT_WIDTH;
    localparam JOB_W = PW * 3; // 24 bits
    localparam BUS_W = 48;     // 3 channels x 16-bit Q4.4

    // =========================================================================
    // 1. Tile Loading Counters and Logic
    // =========================================================================
    reg [1:0]               tile_cnt_a;
    reg [1:0]               tile_cnt_b;
    reg [$clog2(SZI)-1:0]   row_cnt_a;
    reg [$clog2(SZI)-1:0]   row_cnt_b;
    reg                     loading_active;
    reg                     load_done;

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            tile_cnt_a     <= 2'd0;
            tile_cnt_b     <= 2'd0;
            row_cnt_a      <= {$clog2(SZI){1'b0}};
            row_cnt_b      <= {$clog2(SZI){1'b0}};
            loading_active <= 1'b0;
            load_done      <= 1'b0;
        end else begin
            if (start) begin
                loading_active <= 1'b1;
                load_done      <= 1'b0;
                tile_cnt_a     <= 2'd0;
                tile_cnt_b     <= 2'd0;
                row_cnt_a      <= {$clog2(SZI){1'b0}};
                row_cnt_b      <= {$clog2(SZI){1'b0}};
            end else if (loading_active) begin
                if (input_a_val && input_a_rdy) begin
                    if (row_cnt_a == SZI - 1) begin
                        row_cnt_a  <= {$clog2(SZI){1'b0}};
                        tile_cnt_a <= tile_cnt_a + 2'd1;
                    end else begin
                        row_cnt_a  <= row_cnt_a + 1;
                    end
                end

                if (input_b_val && input_b_rdy) begin
                    if (row_cnt_b == SZI - 1) begin
                        row_cnt_b  <= {$clog2(SZI){1'b0}};
                        tile_cnt_b <= tile_cnt_b + 2'd1;
                    end else begin
                        row_cnt_b  <= row_cnt_b + 1;
                    end
                end

                if ((tile_cnt_a == 3 && row_cnt_a == SZI - 1 && input_a_val && input_a_rdy) &&
                    (tile_cnt_b == 3 && row_cnt_b == SZI - 1 && input_b_val && input_b_rdy)) begin
                    loading_active <= 1'b0;
                    load_done      <= 1'b1;
                end
            end else begin
                load_done      <= 1'b0;
            end
        end
    end

    assign input_a_rdy = loading_active;
    assign input_b_rdy = loading_active;

    // =========================================================================
    // 2. Scratchpad Memory Instantiation
    // =========================================================================
    wire [SZI*SZJ*JOB_W-1:0] a11_flat, a12_flat, a21_flat, a22_flat;
    wire [SZI*SZJ*JOB_W-1:0] b11_flat, b12_flat, b21_flat, b22_flat;
    wire [SZI*SZJ*JOB_W-1:0] c11_flat, c12_flat, c21_flat, c22_flat;

    reg  [4:0]              sp_wr_slot;
    reg                     sp_wr_en;
    reg  [$clog2(SZI)-1:0]  sp_wr_row;
    reg  [SZJ*JOB_W-1:0]    sp_wr_data;

    reg  [4:0]              sp_wr_slot_b;
    reg                     sp_wr_en_b;
    reg  [$clog2(SZI)-1:0]  sp_wr_row_b;
    reg  [SZJ*JOB_W-1:0]    sp_wr_data_b;

    wire                    sp_wr_en_c11;
    wire [$clog2(SZI)-1:0]  sp_wr_row_c11;
    wire [SZJ*JOB_W-1:0]    sp_wr_data_c11;

    wire                    sp_wr_en_c12;
    wire [$clog2(SZI)-1:0]  sp_wr_row_c12;
    wire [SZJ*JOB_W-1:0]    sp_wr_data_c12;

    wire                    sp_wr_en_c21;
    wire [$clog2(SZI)-1:0]  sp_wr_row_c21;
    wire [SZJ*JOB_W-1:0]    sp_wr_data_c21;

    wire                    sp_wr_en_c22;
    wire [$clog2(SZI)-1:0]  sp_wr_row_c22;
    wire [SZJ*JOB_W-1:0]    sp_wr_data_c22;

    strassen_scratchpad #(
        .SZI(SZI), .SZJ(SZJ), .POSIT_WIDTH(PW)
    ) scratchpad_inst (
        .clk(clk),
        .resetn(resetn),
        .wr_slot(sp_wr_slot),
        .wr_en(sp_wr_en),
        .wr_row(sp_wr_row),
        .wr_data(sp_wr_data),
        .wr_slot_b(sp_wr_slot_b),
        .wr_en_b(sp_wr_en_b),
        .wr_row_b(sp_wr_row_b),
        .wr_data_b(sp_wr_data_b),
        .wr_en_c11(sp_wr_en_c11),
        .wr_row_c11(sp_wr_row_c11),
        .wr_data_c11(sp_wr_data_c11),
        .wr_en_c12(sp_wr_en_c12),
        .wr_row_c12(sp_wr_row_c12),
        .wr_data_c12(sp_wr_data_c12),
        .wr_en_c21(sp_wr_en_c21),
        .wr_row_c21(sp_wr_row_c21),
        .wr_data_c21(sp_wr_data_c21),
        .wr_en_c22(sp_wr_en_c22),
        .wr_row_c22(sp_wr_row_c22),
        .wr_data_c22(sp_wr_data_c22),
        .a11_flat(a11_flat), .a12_flat(a12_flat), .a21_flat(a21_flat), .a22_flat(a22_flat),
        .b11_flat(b11_flat), .b12_flat(b12_flat), .b21_flat(b21_flat), .b22_flat(b22_flat),
        .c11_flat(c11_flat), .c12_flat(c12_flat), .c21_flat(c21_flat), .c22_flat(c22_flat)
    );

    always @(*) begin
        if (loading_active) begin
            sp_wr_slot       = 5'd2 + tile_cnt_a;
            sp_wr_en         = input_a_val && input_a_rdy;
            sp_wr_row        = row_cnt_a;
            sp_wr_data       = input_a_data;

            sp_wr_slot_b     = 5'd6 + tile_cnt_b;
            sp_wr_en_b       = input_b_val && input_b_rdy;
            sp_wr_row_b      = row_cnt_b;
            sp_wr_data_b     = input_b_data;
        end else begin
            sp_wr_slot       = 5'd0;
            sp_wr_en         = 1'b0;
            sp_wr_row        = {$clog2(SZI){1'b0}};
            sp_wr_data       = {(SZJ*JOB_W){1'b0}};

            sp_wr_slot_b     = 5'd0;
            sp_wr_en_b       = 1'b0;
            sp_wr_row_b      = {$clog2(SZI){1'b0}};
            sp_wr_data_b     = {(SZJ*JOB_W){1'b0}};
        end
    end

    // =========================================================================
    // 3. Controller Instantiation
    // =========================================================================
    wire                            ctrl_done;
    wire                            ctrl_sys_load_weight;
    wire                            ctrl_sys_clear_quire;
    wire                            ctrl_sys_shift_out;
    wire                            ctrl_sys_shift_load;
    wire [3:0]                      ctrl_state;
    wire [7:0]                      ctrl_cnt;

    strassen_controller #(
        .SZI(SZI), .SZJ(SZJ), .POSIT_WIDTH(PW)
    ) controller_inst (
        .clk(clk),
        .resetn(resetn),
        .start(load_done),
        .done(ctrl_done),
        .pre_start(),
        .pre_done(1'b0),
        .post_start1(),
        .post_done1(1'b0),
        .post_start2(),
        .post_done2(1'b0),
        .sys_load_weight(ctrl_sys_load_weight),
        .sys_clear_quire(ctrl_sys_clear_quire),
        .sys_shift_out(ctrl_sys_shift_out),
        .sys_shift_load(ctrl_sys_shift_load),
        .state(ctrl_state),
        .cnt(ctrl_cnt)
    );

    // Pipeline control registers (4-stage delay)
    reg [3:0] load_weight_delay;
    reg [3:0] clear_quire_delay;
    reg [3:0] shift_out_delay;
    reg [3:0] shift_load_delay;

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            load_weight_delay <= 4'b0;
            clear_quire_delay <= 4'b0;
            shift_out_delay   <= 4'b0;
            shift_load_delay  <= 4'b0;
        end else begin
            load_weight_delay <= {load_weight_delay[2:0], ctrl_sys_load_weight};
            clear_quire_delay <= {clear_quire_delay[2:0], ctrl_sys_clear_quire};
            shift_out_delay   <= {shift_out_delay[2:0], ctrl_sys_shift_out};
            shift_load_delay  <= {shift_load_delay[2:0], ctrl_sys_shift_load};
        end
    end

    wire sys_load_weight_aligned = load_weight_delay[3];
    wire sys_clear_quire_aligned = clear_quire_delay[3];
    wire sys_shift_out_aligned   = shift_out_delay[3];
    wire sys_shift_load_aligned  = shift_load_delay[3];

    // =========================================================================
    // 4. Extraction of columns of A and rows of B
    // =========================================================================
    wire [SZI*JOB_W-1:0] a11_col, a12_col, a21_col, a22_col;
    wire [SZJ*JOB_W-1:0] b11_row, b12_row, b21_row, b22_row;

    genvar r_idx;
    generate
        for (r_idx = 0; r_idx < SZI; r_idx = r_idx + 1) begin : col_extract
            assign a11_col[r_idx*JOB_W +: JOB_W] = (ctrl_state == 4'd1 && ctrl_cnt < SZI) ? a11_flat[r_idx*SZJ*JOB_W + ctrl_cnt[$clog2(SZI)-1:0]*JOB_W +: JOB_W] : {JOB_W{1'b0}};
            assign a12_col[r_idx*JOB_W +: JOB_W] = (ctrl_state == 4'd1 && ctrl_cnt < SZI) ? a12_flat[r_idx*SZJ*JOB_W + ctrl_cnt[$clog2(SZI)-1:0]*JOB_W +: JOB_W] : {JOB_W{1'b0}};
            assign a21_col[r_idx*JOB_W +: JOB_W] = (ctrl_state == 4'd1 && ctrl_cnt < SZI) ? a21_flat[r_idx*SZJ*JOB_W + ctrl_cnt[$clog2(SZI)-1:0]*JOB_W +: JOB_W] : {JOB_W{1'b0}};
            assign a22_col[r_idx*JOB_W +: JOB_W] = (ctrl_state == 4'd1 && ctrl_cnt < SZI) ? a22_flat[r_idx*SZJ*JOB_W + ctrl_cnt[$clog2(SZI)-1:0]*JOB_W +: JOB_W] : {JOB_W{1'b0}};
        end
    endgenerate

    assign b11_row = (ctrl_state == 4'd1 && ctrl_cnt < SZI) ? b11_flat[ctrl_cnt[$clog2(SZI)-1:0]*SZJ*JOB_W +: SZJ*JOB_W] : {SZJ*JOB_W{1'b0}};
    assign b12_row = (ctrl_state == 4'd1 && ctrl_cnt < SZI) ? b12_flat[ctrl_cnt[$clog2(SZI)-1:0]*SZJ*JOB_W +: SZJ*JOB_W] : {SZJ*JOB_W{1'b0}};
    assign b21_row = (ctrl_state == 4'd1 && ctrl_cnt < SZI) ? b21_flat[ctrl_cnt[$clog2(SZI)-1:0]*SZJ*JOB_W +: SZJ*JOB_W] : {SZJ*JOB_W{1'b0}};
    assign b22_row = (ctrl_state == 4'd1 && ctrl_cnt < SZI) ? b22_flat[ctrl_cnt[$clog2(SZI)-1:0]*SZJ*JOB_W +: SZJ*JOB_W] : {SZJ*JOB_W{1'b0}};

    // =========================================================================
    // 5. Early Decoders (Multiplexed 8-bit Posit to 16-bit Q4.4 Fixed-Point, 3 channels)
    // =========================================================================
    wire [SZI*BUS_W-1:0] a11_col_fixed, a12_col_fixed, a21_col_fixed, a22_col_fixed;
    wire [SZJ*BUS_W-1:0] b11_row_fixed, b12_row_fixed, b21_row_fixed, b22_row_fixed;

    genvar da, ch;
    generate
        for (da = 0; da < SZI; da = da + 1) begin : dec_a_loop
            for (ch = 0; ch < 3; ch = ch + 1) begin : dec_a_ch_8b
                posit_to_fixed_conv_8b d8_a11 (.in(a11_col[(da*24 + ch*8) +: 8]), .out(a11_col_fixed[(da*48 + ch*16) +: 16]));
                posit_to_fixed_conv_8b d8_a12 (.in(a12_col[(da*24 + ch*8) +: 8]), .out(a12_col_fixed[(da*48 + ch*16) +: 16]));
                posit_to_fixed_conv_8b d8_a21 (.in(a21_col[(da*24 + ch*8) +: 8]), .out(a21_col_fixed[(da*48 + ch*16) +: 16]));
                posit_to_fixed_conv_8b d8_a22 (.in(a22_col[(da*24 + ch*8) +: 8]), .out(a22_col_fixed[(da*48 + ch*16) +: 16]));
            end
        end

        for (da = 0; da < SZJ; da = da + 1) begin : dec_b_loop
            for (ch = 0; ch < 3; ch = ch + 1) begin : dec_b_ch_8b
                posit_to_fixed_conv_8b d8_b11 (.in(b11_row[(da*24 + ch*8) +: 8]), .out(b11_row_fixed[(da*48 + ch*16) +: 16]));
                posit_to_fixed_conv_8b d8_b12 (.in(b12_row[(da*24 + ch*8) +: 8]), .out(b12_row_fixed[(da*48 + ch*16) +: 16]));
                posit_to_fixed_conv_8b d8_b21 (.in(b21_row[(da*24 + ch*8) +: 8]), .out(b21_row_fixed[(da*48 + ch*16) +: 16]));
                posit_to_fixed_conv_8b d8_b22 (.in(b22_row[(da*24 + ch*8) +: 8]), .out(b22_row_fixed[(da*48 + ch*16) +: 16]));
            end
        end
    endgenerate

    // =========================================================================
    // 6. Preprocessing (Fixed-Point additions, 48-bit wide)
    // =========================================================================
    wire [SZI*BUS_W-1:0] prep_a_out_fixed [1:7];

    strassen_preprocess #(.WIDTH(SZI), .DATA_WIDTH(BUS_W)) prep_a_inst1 (.clk(clk), .resetn(resetn), .op_sub(1'b0), .passthrough(1'b0), .in_a(a11_col_fixed), .in_b(a22_col_fixed), .out(prep_a_out_fixed[1]));
    strassen_preprocess #(.WIDTH(SZI), .DATA_WIDTH(BUS_W)) prep_a_inst2 (.clk(clk), .resetn(resetn), .op_sub(1'b0), .passthrough(1'b0), .in_a(a21_col_fixed), .in_b(a22_col_fixed), .out(prep_a_out_fixed[2]));
    strassen_preprocess #(.WIDTH(SZI), .DATA_WIDTH(BUS_W)) prep_a_inst3 (.clk(clk), .resetn(resetn), .op_sub(1'b0), .passthrough(1'b1), .in_a(a11_col_fixed), .in_b({SZI*BUS_W{1'b0}}), .out(prep_a_out_fixed[3]));
    strassen_preprocess #(.WIDTH(SZI), .DATA_WIDTH(BUS_W)) prep_a_inst4 (.clk(clk), .resetn(resetn), .op_sub(1'b0), .passthrough(1'b1), .in_a(a22_col_fixed), .in_b({SZI*BUS_W{1'b0}}), .out(prep_a_out_fixed[4]));
    strassen_preprocess #(.WIDTH(SZI), .DATA_WIDTH(BUS_W)) prep_a_inst5 (.clk(clk), .resetn(resetn), .op_sub(1'b0), .passthrough(1'b0), .in_a(a11_col_fixed), .in_b(a12_col_fixed), .out(prep_a_out_fixed[5]));
    strassen_preprocess #(.WIDTH(SZI), .DATA_WIDTH(BUS_W)) prep_a_inst6 (.clk(clk), .resetn(resetn), .op_sub(1'b1), .passthrough(1'b0), .in_a(a21_col_fixed), .in_b(a11_col_fixed), .out(prep_a_out_fixed[6]));
    strassen_preprocess #(.WIDTH(SZI), .DATA_WIDTH(BUS_W)) prep_a_inst7 (.clk(clk), .resetn(resetn), .op_sub(1'b1), .passthrough(1'b0), .in_a(a12_col_fixed), .in_b(a22_col_fixed), .out(prep_a_out_fixed[7]));

    wire [SZJ*BUS_W-1:0] prep_b_out_fixed [1:7];

    strassen_preprocess #(.WIDTH(SZJ), .DATA_WIDTH(BUS_W)) prep_b_inst1 (.clk(clk), .resetn(resetn), .op_sub(1'b0), .passthrough(1'b0), .in_a(b11_row_fixed), .in_b(b22_row_fixed), .out(prep_b_out_fixed[1]));
    strassen_preprocess #(.WIDTH(SZJ), .DATA_WIDTH(BUS_W)) prep_b_inst2 (.clk(clk), .resetn(resetn), .op_sub(1'b0), .passthrough(1'b1), .in_a(b11_row_fixed), .in_b({SZJ*BUS_W{1'b0}}), .out(prep_b_out_fixed[2]));
    strassen_preprocess #(.WIDTH(SZJ), .DATA_WIDTH(BUS_W)) prep_b_inst3 (.clk(clk), .resetn(resetn), .op_sub(1'b1), .passthrough(1'b0), .in_a(b12_row_fixed), .in_b(b22_row_fixed), .out(prep_b_out_fixed[3]));
    strassen_preprocess #(.WIDTH(SZJ), .DATA_WIDTH(BUS_W)) prep_b_inst4 (.clk(clk), .resetn(resetn), .op_sub(1'b1), .passthrough(1'b0), .in_a(b21_row_fixed), .in_b(b11_row_fixed), .out(prep_b_out_fixed[4]));
    strassen_preprocess #(.WIDTH(SZJ), .DATA_WIDTH(BUS_W)) prep_b_inst5 (.clk(clk), .resetn(resetn), .op_sub(1'b0), .passthrough(1'b1), .in_a(b22_row_fixed), .in_b({SZJ*BUS_W{1'b0}}), .out(prep_b_out_fixed[5]));
    strassen_preprocess #(.WIDTH(SZJ), .DATA_WIDTH(BUS_W)) prep_b_inst6 (.clk(clk), .resetn(resetn), .op_sub(1'b0), .passthrough(1'b0), .in_a(b11_row_fixed), .in_b(b12_row_fixed), .out(prep_b_out_fixed[6]));
    strassen_preprocess #(.WIDTH(SZJ), .DATA_WIDTH(BUS_W)) prep_b_inst7 (.clk(clk), .resetn(resetn), .op_sub(1'b0), .passthrough(1'b0), .in_a(b21_row_fixed), .in_b(b22_row_fixed), .out(prep_b_out_fixed[7]));

    // =========================================================================
    // 7. Instantiate 7 Parallel Matrix Execution Units (MXUs)
    // =========================================================================
    wire [SZJ*BUS_W-1:0] sys_q_out_fixed [1:7];

    genvar m_idx;
    generate
        for (m_idx = 1; m_idx <= 7; m_idx = m_idx + 1) begin : mxu_inst_gen
            posit_mxu #(
                .SZI(SZI), .SZJ(SZJ)
            ) mxu_inst (
                .clk(clk),
                .resetn(resetn),
                .load_weight(sys_load_weight_aligned),
                .clear_quire(sys_clear_quire_aligned),
                .shift_out(sys_shift_out_aligned),
                .shift_load(sys_shift_load_aligned),
                .a(prep_a_out_fixed[m_idx]),
                .b(prep_b_out_fixed[m_idx]),
                .c(sys_q_out_fixed[m_idx])
            );
        end
    endgenerate

    // =========================================================================
    // 8. Postprocessing Stage 1 (Fixed-Point, 48-bit wide)
    // =========================================================================
    wire [SZJ*BUS_W-1:0] post1_out_fixed [1:6];

    strassen_preprocess #(.WIDTH(SZJ), .DATA_WIDTH(BUS_W)) post1_inst1 (.clk(clk), .resetn(resetn), .op_sub(1'b0), .passthrough(1'b0), .in_a(sys_q_out_fixed[1]), .in_b(sys_q_out_fixed[4]), .out(post1_out_fixed[1]));
    strassen_preprocess #(.WIDTH(SZJ), .DATA_WIDTH(BUS_W)) post1_inst2 (.clk(clk), .resetn(resetn), .op_sub(1'b1), .passthrough(1'b0), .in_a(sys_q_out_fixed[7]), .in_b(sys_q_out_fixed[5]), .out(post1_out_fixed[2]));
    strassen_preprocess #(.WIDTH(SZJ), .DATA_WIDTH(BUS_W)) post1_inst3 (.clk(clk), .resetn(resetn), .op_sub(1'b1), .passthrough(1'b0), .in_a(sys_q_out_fixed[1]), .in_b(sys_q_out_fixed[2]), .out(post1_out_fixed[3]));
    strassen_preprocess #(.WIDTH(SZJ), .DATA_WIDTH(BUS_W)) post1_inst4 (.clk(clk), .resetn(resetn), .op_sub(1'b0), .passthrough(1'b0), .in_a(sys_q_out_fixed[3]), .in_b(sys_q_out_fixed[6]), .out(post1_out_fixed[4]));
    strassen_preprocess #(.WIDTH(SZJ), .DATA_WIDTH(BUS_W)) post1_inst5 (.clk(clk), .resetn(resetn), .op_sub(1'b0), .passthrough(1'b0), .in_a(sys_q_out_fixed[3]), .in_b(sys_q_out_fixed[5]), .out(post1_out_fixed[5]));
    strassen_preprocess #(.WIDTH(SZJ), .DATA_WIDTH(BUS_W)) post1_inst6 (.clk(clk), .resetn(resetn), .op_sub(1'b0), .passthrough(1'b0), .in_a(sys_q_out_fixed[2]), .in_b(sys_q_out_fixed[4]), .out(post1_out_fixed[6]));

    // Align delays (4-stage delay pipeline)
    reg [SZJ*BUS_W-1:0] c12_delay_fixed [0:3];
    reg [SZJ*BUS_W-1:0] c21_delay_fixed [0:3];
    integer d_idx;
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            for (d_idx = 0; d_idx < 4; d_idx = d_idx + 1) begin
                c12_delay_fixed[d_idx] <= {(SZJ*BUS_W){1'b0}};
                c21_delay_fixed[d_idx] <= {(SZJ*BUS_W){1'b0}};
            end
        end else begin
            c12_delay_fixed[0] <= post1_out_fixed[5];
            c12_delay_fixed[1] <= c12_delay_fixed[0];
            c12_delay_fixed[2] <= c12_delay_fixed[1];
            c12_delay_fixed[3] <= c12_delay_fixed[2];

            c21_delay_fixed[0] <= post1_out_fixed[6];
            c21_delay_fixed[1] <= c21_delay_fixed[0];
            c21_delay_fixed[2] <= c21_delay_fixed[1];
            c21_delay_fixed[3] <= c21_delay_fixed[2];
        end
    end
    wire [SZJ*BUS_W-1:0] c12_aligned_fixed = c12_delay_fixed[3];
    wire [SZJ*BUS_W-1:0] c21_aligned_fixed = c21_delay_fixed[3];

    // =========================================================================
    // 9. Postprocessing Stage 2 (Fixed-Point, 48-bit wide)
    // =========================================================================
    wire [SZJ*BUS_W-1:0] c11_stage2_fixed;
    wire [SZJ*BUS_W-1:0] c22_stage2_fixed;

    strassen_preprocess #(.WIDTH(SZJ), .DATA_WIDTH(BUS_W)) post2_inst1 (.clk(clk), .resetn(resetn), .op_sub(1'b0), .passthrough(1'b0), .in_a(post1_out_fixed[1]), .in_b(post1_out_fixed[2]), .out(c11_stage2_fixed));
    strassen_preprocess #(.WIDTH(SZJ), .DATA_WIDTH(BUS_W)) post2_inst2 (.clk(clk), .resetn(resetn), .op_sub(1'b0), .passthrough(1'b0), .in_a(post1_out_fixed[3]), .in_b(post1_out_fixed[4]), .out(c22_stage2_fixed));

    // =========================================================================
    // 10. Late Encoders (Q4.4 Fixed-Point to 8-bit Posit, 3 channels)
    // =========================================================================
    wire [SZJ*JOB_W-1:0] c11_stage2;
    wire [SZJ*JOB_W-1:0] c12_aligned;
    wire [SZJ*JOB_W-1:0] c21_aligned;
    wire [SZJ*JOB_W-1:0] c22_stage2;

    genvar ec, ech;
    generate
        for (ec = 0; ec < SZJ; ec = ec + 1) begin : enc_post_gen
            for (ech = 0; ech < 3; ech = ech + 1) begin : enc_post_ch_8b
                fixed_to_posit_conv_8b e8_c11 (.in(c11_stage2_fixed[(ec*48 + ech*16) +: 16]), .out(c11_stage2[(ec*24 + ech*8) +: 8]));
                fixed_to_posit_conv_8b e8_c12 (.in(c12_aligned_fixed[(ec*48 + ech*16) +: 16]), .out(c12_aligned[(ec*24 + ech*8) +: 8]));
                fixed_to_posit_conv_8b e8_c21 (.in(c21_aligned_fixed[(ec*48 + ech*16) +: 16]), .out(c21_aligned[(ec*24 + ech*8) +: 8]));
                fixed_to_posit_conv_8b e8_c22 (.in(c22_stage2_fixed[(ec*48 + ech*16) +: 16]), .out(c22_stage2[(ec*24 + ech*8) +: 8]));
            end
        end
    endgenerate

    // Writeback pipelines (8-stage delay)
    reg [7:0]             post_wr_en_pipe;
    reg [$clog2(SZI)-1:0] post_wr_row_pipe [0:7];

    reg [$clog2(SZI)-1:0] shift_cnt;
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            shift_cnt <= 0;
        end else if (sys_shift_out_aligned) begin
            shift_cnt <= shift_cnt + 1;
        end else begin
            shift_cnt <= 0;
        end
    end

    integer p_idx;
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            post_wr_en_pipe <= 8'b0;
            for (p_idx = 0; p_idx < 8; p_idx = p_idx + 1) begin
                post_wr_row_pipe[p_idx] <= 0;
            end
        end else begin
            post_wr_en_pipe <= {post_wr_en_pipe[6:0], sys_shift_out_aligned};
            post_wr_row_pipe[0] <= SZI - 1 - shift_cnt;
            for (p_idx = 1; p_idx < 8; p_idx = p_idx + 1) begin
                post_wr_row_pipe[p_idx] <= post_wr_row_pipe[p_idx-1];
            end
        end
    end

    wire                   sp_wr_en_c = post_wr_en_pipe[7];
    wire [$clog2(SZI)-1:0] sp_wr_row_c = post_wr_row_pipe[7];

    assign sp_wr_en_c11   = sp_wr_en_c;
    assign sp_wr_row_c11  = sp_wr_row_c;
    assign sp_wr_data_c11 = c11_stage2;

    assign sp_wr_en_c12   = sp_wr_en_c;
    assign sp_wr_row_c12  = sp_wr_row_c;
    assign sp_wr_data_c12 = c12_aligned;

    assign sp_wr_en_c21   = sp_wr_en_c;
    assign sp_wr_row_c21  = sp_wr_row_c;
    assign sp_wr_data_c21 = c21_aligned;

    assign sp_wr_en_c22   = sp_wr_en_c;
    assign sp_wr_row_c22  = sp_wr_row_c;
    assign sp_wr_data_c22 = c22_stage2;

    // =========================================================================
    // 11. Stream Output C tiles with Ready/Valid Handshake
    // =========================================================================
    reg [1:0]               out_tile_cnt;
    reg [$clog2(SZI)-1:0]   out_row_cnt;
    reg                     out_active;
    reg [SZJ*JOB_W-1:0]     gemm_out_row;
    reg                     gemm_out_valid;

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            out_tile_cnt   <= 2'd0;
            out_row_cnt    <= {$clog2(SZI){1'b0}};
            out_active     <= 1'b0;
            gemm_out_row   <= {(SZJ*JOB_W){1'b0}};
            gemm_out_valid <= 1'b0;
        end else begin
            if (ctrl_done) begin
                out_active     <= 1'b1;
                out_tile_cnt   <= 2'd0;
                out_row_cnt    <= {$clog2(SZI){1'b0}};
                gemm_out_valid <= 1'b0;
            end else if (out_active) begin
                if (!gemm_out_valid || out_rdy) begin
                    case (out_tile_cnt)
                        2'd0: gemm_out_row <= c11_flat[out_row_cnt * SZJ * JOB_W +: SZJ * JOB_W];
                        2'd1: gemm_out_row <= c12_flat[out_row_cnt * SZJ * JOB_W +: SZJ * JOB_W];
                        2'd2: gemm_out_row <= c21_flat[out_row_cnt * SZJ * JOB_W +: SZJ * JOB_W];
                        2'd3: gemm_out_row <= c22_flat[out_row_cnt * SZJ * JOB_W +: SZJ * JOB_W];
                    endcase
                    gemm_out_valid <= 1'b1;

                    if (out_row_cnt == SZI - 1) begin
                        out_row_cnt <= {$clog2(SZI){1'b0}};
                        if (out_tile_cnt == 3) begin
                            out_active <= 1'b0;
                        end else begin
                            out_tile_cnt <= out_tile_cnt + 2'd1;
                        end
                    end else begin
                        out_row_cnt <= out_row_cnt + 1;
                    end
                end
            end else begin
                if (out_rdy) begin
                    gemm_out_valid <= 1'b0;
                end
            end
        end
    end

    assign out_val  = gemm_out_valid;
    assign out_data = gemm_out_row;

    reg done_reg;
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            done_reg <= 1'b0;
        end else begin
            done_reg <= out_active && (out_tile_cnt == 3) && (out_row_cnt == SZI - 1) && out_val && out_rdy;
        end
    end
    assign done = done_reg;

endmodule
