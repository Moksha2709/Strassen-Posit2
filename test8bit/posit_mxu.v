// =============================================================================
// posit_mxu.v — Verilog (Delayed Normalization Architecture with Q8.16 Interconnect)
// Matrix Execution Unit: Manages systolic skewing and boundary exponent alignment.
// Dynamic alignment (align_q816) is executed ONCE at the bottom boundary!
// Wide 72-bit interconnect footprint (3 channels x 24-bit Q8.16).
// =============================================================================
`include "posit_pkg.vh"
`include "strassen_pkg.vh"

module posit_mxu #(
    parameter SZI         = `DEFAULT_SZI,
    parameter SZJ         = `DEFAULT_SZJ,
    parameter DATA_WIDTH  = 72
) (
    input  wire                             clk,
    input  wire                             resetn,

    // Control inputs from Strassen Controller
    input  wire                             load_weight,
    input  wire                             clear_quire,
    input  wire                             shift_out,
    input  wire                             shift_load,

    // Vectors (flat: carrying 3 packed 24-bit elements per index = 72 bits)
    input  wire [SZI*DATA_WIDTH-1:0]        a,  // Activations (unskewed fixed-point): 3x 24-bit Q8.16 per row
    input  wire [SZJ*DATA_WIDTH-1:0]        b,  // Weights / Shift-in: 3x 24-bit Q8.16 or accumulators per col
    output wire [SZJ*DATA_WIDTH-1:0]        c   // Outputs (skewed fixed-point accumulators): 3x 24-bit per col
);

    // =========================================================================
    // 1. Boundary Conversion: fixed-point activations to decoded Posit structs (3 channels)
    // =========================================================================
    wire [SZI*36-1:0] a_dec;
    genvar row, ch;
    generate
        for (row = 0; row < SZI; row = row + 1) begin : dec_row_loop
            for (ch = 0; ch < 3; ch = ch + 1) begin : dec_ch_loop
                fixed_to_decoded_conv dec_inst (
                    .in(a[(row*72 + ch*24) +: 24]),
                    .out(a_dec[(row*36 + ch*12) +: 12])
                );
            end
        end
    endgenerate

    // =========================================================================
    // 2. Systolic Activation Skewing (delay row i by i cycles, 36-bit width)
    // =========================================================================
    wire [SZI*36-1:0] a_skewed;
    genvar gi;
    generate
        for (gi = 0; gi < SZI; gi = gi + 1) begin : skew_gen
            if (gi == 0) begin : no_delay
                assign a_skewed[gi*36 +: 36] = a_dec[gi*36 +: 36];
            end else begin : with_delay
                reg [gi*36-1:0] shift_reg;

                always @(posedge clk or negedge resetn) begin
                    if (!resetn) begin
                        shift_reg <= {(gi*36){1'b0}};
                    end else begin
                        if (gi == 1) begin
                            shift_reg[36-1:0] <= a_dec[gi*36 +: 36];
                        end else begin
                            shift_reg <= {shift_reg[(gi-1)*36-1:0], a_dec[gi*36 +: 36]};
                        end
                    end
                end

                assign a_skewed[gi*36 +: 36] = shift_reg[gi*36-1 -: 36];
            end
        end
    endgenerate

    // =========================================================================
    // 3. Systolic Weight/Readout Skewing (delay col j by j cycles, 72-bit / 48-bit width)
    // =========================================================================
    wire [SZJ*72-1:0] b_skewed;
    genvar gj;
    generate
        for (gj = 0; gj < SZJ; gj = gj + 1) begin : skew_gen_b
            if (gj == 0) begin : no_delay_b
                assign b_skewed[gj*72 +: 72] = b[gj*72 +: 72];
            end else begin : with_delay_b
                reg [gj*72-1:0] shift_reg_b;

                always @(posedge clk or negedge resetn) begin
                    if (!resetn) begin
                        shift_reg_b <= {(gj*72){1'b0}};
                    end else begin
                        if (gj == 1) begin
                            shift_reg_b[72-1:0] <= b[gj*72 +: 72];
                        end else begin
                            shift_reg_b <= {shift_reg_b[(gj-1)*72-1:0], b[gj*72 +: 72]};
                        end
                    end
                end

                assign b_skewed[gj*72 +: 72] = shift_reg_b[gj*72-1 -: 72];
            end
        end
    endgenerate

    // =========================================================================
    // 4. Weight/Readout Multiplexing: decode weights to 36-bit Posits
    // =========================================================================
    wire [SZJ*48-1:0] b_in_mux;
    genvar col, cch;
    generate
        for (col = 0; col < SZJ; col = col + 1) begin : weight_dec_loop
            wire [35:0] col_b_dec;
            for (cch = 0; cch < 3; cch = cch + 1) begin : weight_dec_ch
                fixed_to_decoded_conv dec_inst (
                    .in(b_skewed[(col*72 + cch*24) +: 24]),
                    .out(col_b_dec[(cch*12) +: 12])
                );
            end
            assign b_in_mux[col*48 +: 48] = shift_out ? b_skewed[col*72 +: 48] : {12'b0, col_b_dec};
        end
    endgenerate

    // =========================================================================
    // 5. Instantiate Reconfigurable PE Grid
    // =========================================================================
    wire [SZJ*48-1:0] mac_q_out;

    posit_mac_array #(
        .SZI(SZI), .SZJ(SZJ)
    ) mac_array_inst (
        .clk(clk),
        .resetn(resetn),
        .load_weight(load_weight),
        .clear_quire(clear_quire),
        .shift_out(shift_out),
        .shift_load(shift_load),
        .a_in(a_skewed),
        .b_in(b_in_mux),
        .q(mac_q_out)
    );

    // =========================================================================
    // 6. Boundary Exponent Alignment (Delayed Normalization to Q8.16)
    // Performs dynamic exponent shifting ONCE per column output at boundary!
    // =========================================================================
    function automatic [23:0] align_q816_boundary (
        input signed [9:0]   accum,
        input signed [5:0]   scale
    );
        reg signed [23:0] val;
        reg [4:0] sh;
        reg sign;
        reg [9:0] abs_accum;
        begin
            if (accum == 10'sd0) begin
                align_q816_boundary = 24'h000000;
            end else begin
                sign = accum[9];
                abs_accum = sign ? -accum : accum;
                if (scale >= -6'sd10) begin
                    sh = scale[4:0] + 5'd10;
                    val = {14'b0, abs_accum} << sh;
                end else begin
                    sh = -5'd10 - scale[4:0];
                    val = {14'b0, abs_accum} >> sh;
                end
                align_q816_boundary = sign ? -val : val;
            end
        end
    endfunction

    wire [SZJ*72-1:0] c_aligned;
    genvar col_idx, ch_idx;
    generate
        for (col_idx = 0; col_idx < SZJ; col_idx = col_idx + 1) begin : align_col_loop
            for (ch_idx = 0; ch_idx < 3; ch_idx = ch_idx + 1) begin : align_ch_loop
                wire [15:0] ch_word = mac_q_out[(col_idx*48 + ch_idx*16) +: 16];
                wire signed [5:0] ch_scale = ch_word[15:10];
                wire signed [9:0] ch_accum = ch_word[9:0];
                assign c_aligned[(col_idx*72 + ch_idx*24) +: 24] = align_q816_boundary(ch_accum, ch_scale);
            end
        end
    endgenerate

    assign c = c_aligned;

endmodule
