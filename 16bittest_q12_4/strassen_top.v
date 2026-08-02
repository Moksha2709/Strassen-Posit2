// =============================================================================
// strassen_top.v — Verilog
// Parallel multisystolic top-level wrapper for the Fixed-Point Strassen accelerator.
// Computes 16x16 matrix multiplication using 7 parallel systolic arrays.
// Fully concurrent pipelined streaming design.
// =============================================================================
`include "fixed_pkg.vh"
`include "strassen_pkg.vh"

module strassen_top #(
    parameter SZI         = `DEFAULT_SZI,
    parameter SZJ         = `DEFAULT_SZJ,
    parameter DATA_WIDTH  = `DATA_WIDTH,
    parameter FRAC_WIDTH  = `FRAC_WIDTH
) (
    input  wire                             clk,
    input  wire                             resetn,

    // Execution trigger
    input  wire                             start,
    output wire                             done,

    // Input Matrix A (Streaming, row-by-row, tile-by-tile)
    input  wire                             input_a_val,
    input  wire [SZJ*DATA_WIDTH-1:0]        input_a_data,
    output wire                             input_a_rdy,

    // Input Matrix B (Streaming, row-by-row, tile-by-tile)
    input  wire                             input_b_val,
    input  wire [SZJ*DATA_WIDTH-1:0]        input_b_data,
    output wire                             input_b_rdy,

    // Output Matrix C (Streaming, row-by-row, tile-by-tile)
    output wire                             out_val,
    output wire [SZJ*DATA_WIDTH-1:0]        out_data,
    input  wire                             out_rdy
);

    localparam DW = DATA_WIDTH;

    // --- Tile Loading Counters and Logic ---
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

                // Done loading when both A and B have loaded all 4 tiles
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

    // --- Instantiate the Posit Scratchpad ---
    wire [SZI*SZJ*DW-1:0] a11_flat, a12_flat, a21_flat, a22_flat;
    wire [SZI*SZJ*DW-1:0] b11_flat, b12_flat, b21_flat, b22_flat;
    wire [SZI*SZJ*DW-1:0] c11_flat, c12_flat, c21_flat, c22_flat;

    reg  [4:0]                       sp_wr_slot;
    reg                             sp_wr_en;
    reg  [$clog2(SZI)-1:0]           sp_wr_row;
    reg  [SZJ*DW-1:0]                sp_wr_data;

    reg  [4:0]                       sp_wr_slot_b;
    reg                             sp_wr_en_b;
    reg  [$clog2(SZI)-1:0]           sp_wr_row_b;
    reg  [SZJ*DW-1:0]                sp_wr_data_b;

    wire                            sp_wr_en_c11;
    wire [$clog2(SZI)-1:0]          sp_wr_row_c11;
    wire [SZJ*DW-1:0]               sp_wr_data_c11;

    wire                            sp_wr_en_c12;
    wire [$clog2(SZI)-1:0]          sp_wr_row_c12;
    wire [SZJ*DW-1:0]               sp_wr_data_c12;

    wire                            sp_wr_en_c21;
    wire [$clog2(SZI)-1:0]          sp_wr_row_c21;
    wire [SZJ*DW-1:0]               sp_wr_data_c21;

    wire                            sp_wr_en_c22;
    wire [$clog2(SZI)-1:0]          sp_wr_row_c22;
    wire [SZJ*DW-1:0]               sp_wr_data_c22;

    strassen_scratchpad #(
        .SZI(SZI), .SZJ(SZJ), .DATA_WIDTH(DW)
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

    // --- Route loading data to scratchpad ---
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
            sp_wr_data       = {(SZJ*DW){1'b0}};

            sp_wr_slot_b     = 5'd0;
            sp_wr_en_b       = 1'b0;
            sp_wr_row_b      = {$clog2(SZI){1'b0}};
            sp_wr_data_b     = {(SZJ*DW){1'b0}};
        end
    end

    // --- Instantiate the Strassen Controller ---
    wire                            ctrl_done;
    wire                            ctrl_sys_load_weight;
    wire                            ctrl_sys_clear_quire;
    wire                            ctrl_sys_shift_out;
    wire                            ctrl_sys_shift_load;

    wire [3:0]                      ctrl_state;
    wire [7:0]                      ctrl_cnt;

    strassen_controller #(
        .SZI(SZI), .SZJ(SZJ), .DATA_WIDTH(DW)
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

    // --- Control Signal Delay Pipelines (4-stage delay) ---
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

    // --- Extraction of A columns and B rows from Scratchpad ---
    wire [SZI*DW-1:0] a11_col;
    wire [SZI*DW-1:0] a12_col;
    wire [SZI*DW-1:0] a21_col;
    wire [SZI*DW-1:0] a22_col;

    genvar r_idx;
    generate
        for (r_idx = 0; r_idx < SZI; r_idx = r_idx + 1) begin : col_extract
            assign a11_col[r_idx*DW +: DW] = (ctrl_state == 4'd1 && ctrl_cnt < SZI) ? a11_flat[r_idx*SZJ*DW + ctrl_cnt[$clog2(SZI)-1:0]*DW +: DW] : {DW{1'b0}};
            assign a12_col[r_idx*DW +: DW] = (ctrl_state == 4'd1 && ctrl_cnt < SZI) ? a12_flat[r_idx*SZJ*DW + ctrl_cnt[$clog2(SZI)-1:0]*DW +: DW] : {DW{1'b0}};
            assign a21_col[r_idx*DW +: DW] = (ctrl_state == 4'd1 && ctrl_cnt < SZI) ? a21_flat[r_idx*SZJ*DW + ctrl_cnt[$clog2(SZI)-1:0]*DW +: DW] : {DW{1'b0}};
            assign a22_col[r_idx*DW +: DW] = (ctrl_state == 4'd1 && ctrl_cnt < SZI) ? a22_flat[r_idx*SZJ*DW + ctrl_cnt[$clog2(SZI)-1:0]*DW +: DW] : {DW{1'b0}};
        end
    endgenerate

    wire [SZJ*DW-1:0] b11_row;
    wire [SZJ*DW-1:0] b12_row;
    wire [SZJ*DW-1:0] b21_row;
    wire [SZJ*DW-1:0] b22_row;

    assign b11_row = (ctrl_state == 4'd1 && ctrl_cnt < SZI) ? b11_flat[ctrl_cnt[$clog2(SZI)-1:0]*SZJ*DW +: SZJ*DW] : {SZJ*DW{1'b0}};
    assign b12_row = (ctrl_state == 4'd1 && ctrl_cnt < SZI) ? b12_flat[ctrl_cnt[$clog2(SZI)-1:0]*SZJ*DW +: SZJ*DW] : {SZJ*DW{1'b0}};
    assign b21_row = (ctrl_state == 4'd1 && ctrl_cnt < SZI) ? b21_flat[ctrl_cnt[$clog2(SZI)-1:0]*SZJ*DW +: SZJ*DW] : {SZJ*DW{1'b0}};
    assign b22_row = (ctrl_state == 4'd1 && ctrl_cnt < SZI) ? b22_flat[ctrl_cnt[$clog2(SZI)-1:0]*SZJ*DW +: SZJ*DW] : {SZJ*DW{1'b0}};

    // --- Instantiate 7 Parallel Preprocessors for Activations A (SZI width) ---
    wire [SZI*DW-1:0] prep_a_out [1:7];

    // M1 = (A11 + A22)
    strassen_preprocess #(.WIDTH(SZI), .DATA_WIDTH(DW), .FRAC_WIDTH(FRAC_WIDTH)) prep_a_inst1 (
        .clk(clk), .resetn(resetn), .op_sub(1'b0), .passthrough(1'b0),
        .in_a(a11_col), .in_b(a22_col), .out(prep_a_out[1])
    );
    // M2 = (A21 + A22)
    strassen_preprocess #(.WIDTH(SZI), .DATA_WIDTH(DW), .FRAC_WIDTH(FRAC_WIDTH)) prep_a_inst2 (
        .clk(clk), .resetn(resetn), .op_sub(1'b0), .passthrough(1'b0),
        .in_a(a21_col), .in_b(a22_col), .out(prep_a_out[2])
    );
    // M3 = A11
    strassen_preprocess #(.WIDTH(SZI), .DATA_WIDTH(DW), .FRAC_WIDTH(FRAC_WIDTH)) prep_a_inst3 (
        .clk(clk), .resetn(resetn), .op_sub(1'b0), .passthrough(1'b1),
        .in_a(a11_col), .in_b({SZI*DW{1'b0}}), .out(prep_a_out[3])
    );
    // M4 = A22
    strassen_preprocess #(.WIDTH(SZI), .DATA_WIDTH(DW), .FRAC_WIDTH(FRAC_WIDTH)) prep_a_inst4 (
        .clk(clk), .resetn(resetn), .op_sub(1'b0), .passthrough(1'b1),
        .in_a(a22_col), .in_b({SZI*DW{1'b0}}), .out(prep_a_out[4])
    );
    // M5 = (A11 + A12)
    strassen_preprocess #(.WIDTH(SZI), .DATA_WIDTH(DW), .FRAC_WIDTH(FRAC_WIDTH)) prep_a_inst5 (
        .clk(clk), .resetn(resetn), .op_sub(1'b0), .passthrough(1'b0),
        .in_a(a11_col), .in_b(a12_col), .out(prep_a_out[5])
    );
    // M6 = (A21 - A11)
    strassen_preprocess #(.WIDTH(SZI), .DATA_WIDTH(DW), .FRAC_WIDTH(FRAC_WIDTH)) prep_a_inst6 (
        .clk(clk), .resetn(resetn), .op_sub(1'b1), .passthrough(1'b0),
        .in_a(a21_col), .in_b(a11_col), .out(prep_a_out[6])
    );
    // M7 = (A12 - A22)
    strassen_preprocess #(.WIDTH(SZI), .DATA_WIDTH(DW), .FRAC_WIDTH(FRAC_WIDTH)) prep_a_inst7 (
        .clk(clk), .resetn(resetn), .op_sub(1'b1), .passthrough(1'b0),
        .in_a(a12_col), .in_b(a22_col), .out(prep_a_out[7])
    );

    // --- Instantiate 7 Parallel Preprocessors for Weights B (SZJ width) ---
    wire [SZJ*DW-1:0] prep_b_out [1:7];

    // M1 = (B11 + B22)
    strassen_preprocess #(.WIDTH(SZJ), .DATA_WIDTH(DW), .FRAC_WIDTH(FRAC_WIDTH)) prep_b_inst1 (
        .clk(clk), .resetn(resetn), .op_sub(1'b0), .passthrough(1'b0),
        .in_a(b11_row), .in_b(b22_row), .out(prep_b_out[1])
    );
    // M2 = B11
    strassen_preprocess #(.WIDTH(SZJ), .DATA_WIDTH(DW), .FRAC_WIDTH(FRAC_WIDTH)) prep_b_inst2 (
        .clk(clk), .resetn(resetn), .op_sub(1'b0), .passthrough(1'b1),
        .in_a(b11_row), .in_b({SZJ*DW{1'b0}}), .out(prep_b_out[2])
    );
    // M3 = (B12 - B22)
    strassen_preprocess #(.WIDTH(SZJ), .DATA_WIDTH(DW), .FRAC_WIDTH(FRAC_WIDTH)) prep_b_inst3 (
        .clk(clk), .resetn(resetn), .op_sub(1'b1), .passthrough(1'b0),
        .in_a(b12_row), .in_b(b22_row), .out(prep_b_out[3])
    );
    // M4 = (B21 - B11)
    strassen_preprocess #(.WIDTH(SZJ), .DATA_WIDTH(DW), .FRAC_WIDTH(FRAC_WIDTH)) prep_b_inst4 (
        .clk(clk), .resetn(resetn), .op_sub(1'b1), .passthrough(1'b0),
        .in_a(b21_row), .in_b(b11_row), .out(prep_b_out[4])
    );
    // M5 = B22
    strassen_preprocess #(.WIDTH(SZJ), .DATA_WIDTH(DW), .FRAC_WIDTH(FRAC_WIDTH)) prep_b_inst5 (
        .clk(clk), .resetn(resetn), .op_sub(1'b0), .passthrough(1'b1),
        .in_a(b22_row), .in_b({SZJ*DW{1'b0}}), .out(prep_b_out[5])
    );
    // M6 = (B11 + B12)
    strassen_preprocess #(.WIDTH(SZJ), .DATA_WIDTH(DW), .FRAC_WIDTH(FRAC_WIDTH)) prep_b_inst6 (
        .clk(clk), .resetn(resetn), .op_sub(1'b0), .passthrough(1'b0),
        .in_a(b11_row), .in_b(b12_row), .out(prep_b_out[6])
    );
    // M7 = (B21 + B22)
    strassen_preprocess #(.WIDTH(SZJ), .DATA_WIDTH(DW), .FRAC_WIDTH(FRAC_WIDTH)) prep_b_inst7 (
        .clk(clk), .resetn(resetn), .op_sub(1'b0), .passthrough(1'b0),
        .in_a(b21_row), .in_b(b22_row), .out(prep_b_out[7])
    );

    // --- Instantiate 7 Parallel Systolic Matrix Execution Units ---
    wire [SZJ*DW-1:0] sys_q_out [1:7];

    genvar m_idx;
    generate
        for (m_idx = 1; m_idx <= 7; m_idx = m_idx + 1) begin : mxu_inst_gen
            fixed_mxu #(
                .SZI(SZI), .SZJ(SZJ),
                .DATA_WIDTH(DW), .FRAC_WIDTH(FRAC_WIDTH)
            ) mxu_inst (
                .clk(clk),
                .resetn(resetn),
                .load_weight(sys_load_weight_aligned),
                .clear_quire(sys_clear_quire_aligned),
                .shift_out(sys_shift_out_aligned),
                .shift_load(sys_shift_load_aligned),
                .a(prep_a_out[m_idx]),
                .b(prep_b_out[m_idx]),
                .c(sys_q_out[m_idx])
            );
        end
    endgenerate

    // --- Postprocessor Stage 1 (6 parallel lanes, SZJ width) ---
    wire [SZJ*DW-1:0] post1_out [1:6];

    // 1: T1 = M1 + M4
    strassen_preprocess #(.WIDTH(SZJ), .DATA_WIDTH(DW), .FRAC_WIDTH(FRAC_WIDTH)) post1_inst1 (
        .clk(clk), .resetn(resetn), .op_sub(1'b0), .passthrough(1'b0),
        .in_a(sys_q_out[1]), .in_b(sys_q_out[4]), .out(post1_out[1])
    );
    // 2: T2 = M7 - M5
    strassen_preprocess #(.WIDTH(SZJ), .DATA_WIDTH(DW), .FRAC_WIDTH(FRAC_WIDTH)) post1_inst2 (
        .clk(clk), .resetn(resetn), .op_sub(1'b1), .passthrough(1'b0),
        .in_a(sys_q_out[7]), .in_b(sys_q_out[5]), .out(post1_out[2])
    );
    // 3: T3 = M1 - M2
    strassen_preprocess #(.WIDTH(SZJ), .DATA_WIDTH(DW), .FRAC_WIDTH(FRAC_WIDTH)) post1_inst3 (
        .clk(clk), .resetn(resetn), .op_sub(1'b1), .passthrough(1'b0),
        .in_a(sys_q_out[1]), .in_b(sys_q_out[2]), .out(post1_out[3])
    );
    // 4: T4 = M3 + M6
    strassen_preprocess #(.WIDTH(SZJ), .DATA_WIDTH(DW), .FRAC_WIDTH(FRAC_WIDTH)) post1_inst4 (
        .clk(clk), .resetn(resetn), .op_sub(1'b0), .passthrough(1'b0),
        .in_a(sys_q_out[3]), .in_b(sys_q_out[6]), .out(post1_out[4])
    );
    // 5: C12 = M3 + M5 (stage 1 output, needs delay)
    strassen_preprocess #(.WIDTH(SZJ), .DATA_WIDTH(DW), .FRAC_WIDTH(FRAC_WIDTH)) post1_inst5 (
        .clk(clk), .resetn(resetn), .op_sub(1'b0), .passthrough(1'b0),
        .in_a(sys_q_out[3]), .in_b(sys_q_out[5]), .out(post1_out[5])
    );
    // 6: C21 = M2 + M4 (stage 1 output, needs delay)
    strassen_preprocess #(.WIDTH(SZJ), .DATA_WIDTH(DW), .FRAC_WIDTH(FRAC_WIDTH)) post1_inst6 (
        .clk(clk), .resetn(resetn), .op_sub(1'b0), .passthrough(1'b0),
        .in_a(sys_q_out[2]), .in_b(sys_q_out[4]), .out(post1_out[6])
    );

    // 4-stage delay pipeline to align C12 and C21 with Stage 2 outputs
    reg [SZJ*DW-1:0] c12_delay [0:3];
    reg [SZJ*DW-1:0] c21_delay [0:3];
    integer d_idx;
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            for (d_idx = 0; d_idx < 4; d_idx = d_idx + 1) begin
                c12_delay[d_idx] <= {(SZJ*DW){1'b0}};
                c21_delay[d_idx] <= {(SZJ*DW){1'b0}};
            end
        end else begin
            c12_delay[0] <= post1_out[5];
            c12_delay[1] <= c12_delay[0];
            c12_delay[2] <= c12_delay[1];
            c12_delay[3] <= c12_delay[2];

            c21_delay[0] <= post1_out[6];
            c21_delay[1] <= c21_delay[0];
            c21_delay[2] <= c21_delay[1];
            c21_delay[3] <= c21_delay[2];
        end
    end
    wire [SZJ*DW-1:0] c12_aligned = c12_delay[3];
    wire [SZJ*DW-1:0] c21_aligned = c21_delay[3];

    // --- Postprocessor Stage 2 (2 parallel lanes, SZJ width) ---
    wire [SZJ*DW-1:0] c11_stage2;
    wire [SZJ*DW-1:0] c22_stage2;

    // 1: C11 = T1 + T2
    strassen_preprocess #(.WIDTH(SZJ), .DATA_WIDTH(DW), .FRAC_WIDTH(FRAC_WIDTH)) post2_inst1 (
        .clk(clk), .resetn(resetn), .op_sub(1'b0), .passthrough(1'b0),
        .in_a(post1_out[1]), .in_b(post1_out[2]), .out(c11_stage2)
    );
    // 2: C22 = T3 + T4
    strassen_preprocess #(.WIDTH(SZJ), .DATA_WIDTH(DW), .FRAC_WIDTH(FRAC_WIDTH)) post2_inst2 (
        .clk(clk), .resetn(resetn), .op_sub(1'b0), .passthrough(1'b0),
        .in_a(post1_out[3]), .in_b(post1_out[4]), .out(c22_stage2)
    );

    // --- Writeback address and control delay pipelines (8-stage delay) ---
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

    // --- Stream Output C tiles with Ready/Valid Handshake ---
    reg [1:0]               out_tile_cnt;
    reg [$clog2(SZI)-1:0]   out_row_cnt;
    reg                     out_active;
    reg [SZJ*DW-1:0]        gemm_out_row;
    reg                     gemm_out_valid;

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            out_tile_cnt   <= 2'd0;
            out_row_cnt    <= {$clog2(SZI){1'b0}};
            out_active     <= 1'b0;
            gemm_out_row   <= {(SZJ*DW){1'b0}};
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
                        2'd0: gemm_out_row <= c11_flat[out_row_cnt * SZJ * DW +: SZJ * DW];
                        2'd1: gemm_out_row <= c12_flat[out_row_cnt * SZJ * DW +: SZJ * DW];
                        2'd2: gemm_out_row <= c21_flat[out_row_cnt * SZJ * DW +: SZJ * DW];
                        2'd3: gemm_out_row <= c22_flat[out_row_cnt * SZJ * DW +: SZJ * DW];
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

    // Pulse done for 1 cycle after the last output row is accepted
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
