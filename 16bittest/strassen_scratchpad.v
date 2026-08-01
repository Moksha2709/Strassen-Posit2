// =============================================================================
// strassen_scratchpad.v — Verilog
// 14-slot scratchpad memory for Strassen operands & results with parallel write ports
// Slots: 2..5=A11..A22, 6..9=B11..B22, 10..13=C11..C22
// =============================================================================
`include "fixed_pkg.vh"
`include "strassen_pkg.vh"

module strassen_scratchpad #(
    parameter SZI         = `DEFAULT_SZI,
    parameter SZJ         = `DEFAULT_SZJ,
    parameter DATA_WIDTH  = `DATA_WIDTH
) (
    input  wire                             clk,
    input  wire                             resetn,

    // Write port A (for A matrix loading)
    input  wire [4:0]                       wr_slot,
    input  wire                             wr_en,
    input  wire [$clog2(SZI)-1:0]           wr_row,
    input  wire [SZJ*DATA_WIDTH-1:0]        wr_data,

    // Write port B (for B matrix loading)
    input  wire [4:0]                       wr_slot_b,
    input  wire                             wr_en_b,
    input  wire [$clog2(SZI)-1:0]           wr_row_b,
    input  wire [SZJ*DATA_WIDTH-1:0]        wr_data_b,

    // Parallel write ports for output quadrants C11..C22
    input  wire                             wr_en_c11,
    input  wire [$clog2(SZI)-1:0]           wr_row_c11,
    input  wire [SZJ*DATA_WIDTH-1:0]        wr_data_c11,

    input  wire                             wr_en_c12,
    input  wire [$clog2(SZI)-1:0]           wr_row_c12,
    input  wire [SZJ*DATA_WIDTH-1:0]       wr_data_c12,

    input  wire                             wr_en_c21,
    input  wire [$clog2(SZI)-1:0]           wr_row_c21,
    input  wire [SZJ*DATA_WIDTH-1:0]       wr_data_c21,

    input  wire                             wr_en_c22,
    input  wire [$clog2(SZI)-1:0]           wr_row_c22,
    input  wire [SZJ*DATA_WIDTH-1:0]       wr_data_c22,

    // Parallel flat read ports for slots 2..13
    output wire [SZI*SZJ*DATA_WIDTH-1:0]    a11_flat,
    output wire [SZI*SZJ*DATA_WIDTH-1:0]    a12_flat,
    output wire [SZI*SZJ*DATA_WIDTH-1:0]    a21_flat,
    output wire [SZI*SZJ*DATA_WIDTH-1:0]    a22_flat,
    output wire [SZI*SZJ*DATA_WIDTH-1:0]    b11_flat,
    output wire [SZI*SZJ*DATA_WIDTH-1:0]    b12_flat,
    output wire [SZI*SZJ*DATA_WIDTH-1:0]    b21_flat,
    output wire [SZI*SZJ*DATA_WIDTH-1:0]    b22_flat,
    output wire [SZI*SZJ*DATA_WIDTH-1:0]    c11_flat,
    output wire [SZI*SZJ*DATA_WIDTH-1:0]    c12_flat,
    output wire [SZI*SZJ*DATA_WIDTH-1:0]    c21_flat,
    output wire [SZI*SZJ*DATA_WIDTH-1:0]    c22_flat
);

    localparam DW = DATA_WIDTH;

    // 14 slots x SZI rows, each row is SZJ*DATA_WIDTH bits wide
    (* ram_style = "block" *) reg [SZJ*DW-1:0] mem [0:13][0:SZI-1];

    // Write ports logic
    integer ws, wr;
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            for (ws = 0; ws < 14; ws = ws + 1)
                for (wr = 0; wr < SZI; wr = wr + 1)
                    mem[ws][wr] <= {(SZJ*DW){1'b0}};
        end else begin
            if (wr_en && (wr_slot < 14)) begin
                mem[wr_slot][wr_row] <= wr_data;
            end
            if (wr_en_b && (wr_slot_b < 14)) begin
                mem[wr_slot_b][wr_row_b] <= wr_data_b;
            end
            if (wr_en_c11) begin
                mem[10][wr_row_c11] <= wr_data_c11;
            end
            if (wr_en_c12) begin
                mem[11][wr_row_c12] <= wr_data_c12;
            end
            if (wr_en_c21) begin
                mem[12][wr_row_c21] <= wr_data_c21;
            end
            if (wr_en_c22) begin
                mem[13][wr_row_c22] <= wr_data_c22;
            end
        end
    end

    // Flat read ports assignment
    genvar r;
    generate
        for (r = 0; r < SZI; r = r + 1) begin : flatten_gen
            assign a11_flat[r*SZJ*DW +: SZJ*DW] = mem[2][r];
            assign a12_flat[r*SZJ*DW +: SZJ*DW] = mem[3][r];
            assign a21_flat[r*SZJ*DW +: SZJ*DW] = mem[4][r];
            assign a22_flat[r*SZJ*DW +: SZJ*DW] = mem[5][r];
            assign b11_flat[r*SZJ*DW +: SZJ*DW] = mem[6][r];
            assign b12_flat[r*SZJ*DW +: SZJ*DW] = mem[7][r];
            assign b21_flat[r*SZJ*DW +: SZJ*DW] = mem[8][r];
            assign b22_flat[r*SZJ*DW +: SZJ*DW] = mem[9][r];
            assign c11_flat[r*SZJ*DW +: SZJ*DW] = mem[10][r];
            assign c12_flat[r*SZJ*DW +: SZJ*DW] = mem[11][r];
            assign c21_flat[r*SZJ*DW +: SZJ*DW] = mem[12][r];
            assign c22_flat[r*SZJ*DW +: SZJ*DW] = mem[13][r];
        end
    endgenerate

endmodule
