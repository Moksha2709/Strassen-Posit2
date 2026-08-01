// =============================================================================
// strassen_scratchpad.v — Verilog
// Triple-Job Scratchpad Memory for Triple-Packed Strassen Accelerator
// Stores three packed jobs (A1, A2, A3) and (B1, B2, B3) in parallel.
// Each word is SZJ * 24 bits wide (carrying three 8-bit elements per column index).
// =============================================================================
`include "posit_pkg.vh"
`include "strassen_pkg.vh"

module strassen_scratchpad #(
    parameter SZI         = `DEFAULT_SZI,
    parameter SZJ         = `DEFAULT_SZJ,
    parameter POSIT_WIDTH = `POSIT_WIDTH
) (
    input  wire                             clk,
    input  wire                             resetn,

    // Write port A (for A matrix loading - carries 3 packed jobs)
    input  wire [4:0]                       wr_slot,
    input  wire                             wr_en,
    input  wire [$clog2(SZI)-1:0]           wr_row,
    input  wire [SZJ*POSIT_WIDTH*3-1:0]     wr_data,

    // Write port B (for B matrix loading - carries 3 packed jobs)
    input  wire [4:0]                       wr_slot_b,
    input  wire                             wr_en_b,
    input  wire [$clog2(SZI)-1:0]           wr_row_b,
    input  wire [SZJ*POSIT_WIDTH*3-1:0]     wr_data_b,

    // Parallel write ports for output quadrants C11..C22 (3 packed jobs)
    input  wire                             wr_en_c11,
    input  wire [$clog2(SZI)-1:0]           wr_row_c11,
    input  wire [SZJ*POSIT_WIDTH*3-1:0]     wr_data_c11,

    input  wire                             wr_en_c12,
    input  wire [$clog2(SZI)-1:0]           wr_row_c12,
    input  wire [SZJ*POSIT_WIDTH*3-1:0]     wr_data_c12,

    input  wire                             wr_en_c21,
    input  wire [$clog2(SZI)-1:0]           wr_row_c21,
    input  wire [SZJ*POSIT_WIDTH*3-1:0]     wr_data_c21,

    input  wire                             wr_en_c22,
    input  wire [$clog2(SZI)-1:0]           wr_row_c22,
    input  wire [SZJ*POSIT_WIDTH*3-1:0]     wr_data_c22,

    // Parallel flat read ports for slots 2..13 (carrying 3 packed jobs)
    output wire [SZI*SZJ*POSIT_WIDTH*3-1:0] a11_flat,
    output wire [SZI*SZJ*POSIT_WIDTH*3-1:0] a12_flat,
    output wire [SZI*SZJ*POSIT_WIDTH*3-1:0] a21_flat,
    output wire [SZI*SZJ*POSIT_WIDTH*3-1:0] a22_flat,
    output wire [SZI*SZJ*POSIT_WIDTH*3-1:0] b11_flat,
    output wire [SZI*SZJ*POSIT_WIDTH*3-1:0] b12_flat,
    output wire [SZI*SZJ*POSIT_WIDTH*3-1:0] b21_flat,
    output wire [SZI*SZJ*POSIT_WIDTH*3-1:0] b22_flat,
    output wire [SZI*SZJ*POSIT_WIDTH*3-1:0] c11_flat,
    output wire [SZI*SZJ*POSIT_WIDTH*3-1:0] c12_flat,
    output wire [SZI*SZJ*POSIT_WIDTH*3-1:0] c21_flat,
    output wire [SZI*SZJ*POSIT_WIDTH*3-1:0] c22_flat
);

    localparam PW = POSIT_WIDTH;
    localparam JOB_W = PW * 3; // 24 bits

    // 14 slot arrays x SZI rows, each row is SZJ*24 bits wide
    (* ram_style = "block" *) reg [SZJ*JOB_W-1:0] slot0  [0:SZI-1];
    (* ram_style = "block" *) reg [SZJ*JOB_W-1:0] slot1  [0:SZI-1];
    (* ram_style = "block" *) reg [SZJ*JOB_W-1:0] slot2  [0:SZI-1];
    (* ram_style = "block" *) reg [SZJ*JOB_W-1:0] slot3  [0:SZI-1];
    (* ram_style = "block" *) reg [SZJ*JOB_W-1:0] slot4  [0:SZI-1];
    (* ram_style = "block" *) reg [SZJ*JOB_W-1:0] slot5  [0:SZI-1];
    (* ram_style = "block" *) reg [SZJ*JOB_W-1:0] slot6  [0:SZI-1];
    (* ram_style = "block" *) reg [SZJ*JOB_W-1:0] slot7  [0:SZI-1];
    (* ram_style = "block" *) reg [SZJ*JOB_W-1:0] slot8  [0:SZI-1];
    (* ram_style = "block" *) reg [SZJ*JOB_W-1:0] slot9  [0:SZI-1];
    (* ram_style = "block" *) reg [SZJ*JOB_W-1:0] slot10 [0:SZI-1];
    (* ram_style = "block" *) reg [SZJ*JOB_W-1:0] slot11 [0:SZI-1];
    (* ram_style = "block" *) reg [SZJ*JOB_W-1:0] slot12 [0:SZI-1];
    (* ram_style = "block" *) reg [SZJ*JOB_W-1:0] slot13 [0:SZI-1];

    // Write ports logic (no async reset loop on memory arrays to allow RAM inference)
    always @(posedge clk) begin
        if (wr_en) begin
            case (wr_slot)
                5'd0:  slot0[wr_row]  <= wr_data;
                5'd1:  slot1[wr_row]  <= wr_data;
                5'd2:  slot2[wr_row]  <= wr_data;
                5'd3:  slot3[wr_row]  <= wr_data;
                5'd4:  slot4[wr_row]  <= wr_data;
                5'd5:  slot5[wr_row]  <= wr_data;
                5'd6:  slot6[wr_row]  <= wr_data;
                5'd7:  slot7[wr_row]  <= wr_data;
                5'd8:  slot8[wr_row]  <= wr_data;
                5'd9:  slot9[wr_row]  <= wr_data;
                5'd10: slot10[wr_row] <= wr_data;
                5'd11: slot11[wr_row] <= wr_data;
                5'd12: slot12[wr_row] <= wr_data;
                5'd13: slot13[wr_row] <= wr_data;
            endcase
        end
        if (wr_en_b) begin
            case (wr_slot_b)
                5'd0:  slot0[wr_row_b]  <= wr_data_b;
                5'd1:  slot1[wr_row_b]  <= wr_data_b;
                5'd2:  slot2[wr_row_b]  <= wr_data_b;
                5'd3:  slot3[wr_row_b]  <= wr_data_b;
                5'd4:  slot4[wr_row_b]  <= wr_data_b;
                5'd5:  slot5[wr_row_b]  <= wr_data_b;
                5'd6:  slot6[wr_row_b]  <= wr_data_b;
                5'd7:  slot7[wr_row_b]  <= wr_data_b;
                5'd8:  slot8[wr_row_b]  <= wr_data_b;
                5'd9:  slot9[wr_row_b]  <= wr_data_b;
                5'd10: slot10[wr_row_b] <= wr_data_b;
                5'd11: slot11[wr_row_b] <= wr_data_b;
                5'd12: slot12[wr_row_b] <= wr_data_b;
                5'd13: slot13[wr_row_b] <= wr_data_b;
            endcase
        end
        if (wr_en_c11) slot10[wr_row_c11] <= wr_data_c11;
        if (wr_en_c12) slot11[wr_row_c12] <= wr_data_c12;
        if (wr_en_c21) slot12[wr_row_c21] <= wr_data_c21;
        if (wr_en_c22) slot13[wr_row_c22] <= wr_data_c22;
    end

    // Synchronous registered read ports for true RAM / BRAM inference
    reg [SZI*SZJ*JOB_W-1:0] a11_flat_reg, a12_flat_reg, a21_flat_reg, a22_flat_reg;
    reg [SZI*SZJ*JOB_W-1:0] b11_flat_reg, b12_flat_reg, b21_flat_reg, b22_flat_reg;
    reg [SZI*SZJ*JOB_W-1:0] c11_flat_reg, c12_flat_reg, c21_flat_reg, c22_flat_reg;

    integer r;
    always @(posedge clk) begin
        for (r = 0; r < SZI; r = r + 1) begin
            a11_flat_reg[r*SZJ*JOB_W +: SZJ*JOB_W] <= slot2[r];
            a12_flat_reg[r*SZJ*JOB_W +: SZJ*JOB_W] <= slot3[r];
            a21_flat_reg[r*SZJ*JOB_W +: SZJ*JOB_W] <= slot4[r];
            a22_flat_reg[r*SZJ*JOB_W +: SZJ*JOB_W] <= slot5[r];
            b11_flat_reg[r*SZJ*JOB_W +: SZJ*JOB_W] <= slot6[r];
            b12_flat_reg[r*SZJ*JOB_W +: SZJ*JOB_W] <= slot7[r];
            b21_flat_reg[r*SZJ*JOB_W +: SZJ*JOB_W] <= slot8[r];
            b22_flat_reg[r*SZJ*JOB_W +: SZJ*JOB_W] <= slot9[r];
            c11_flat_reg[r*SZJ*JOB_W +: SZJ*JOB_W] <= slot10[r];
            c12_flat_reg[r*SZJ*JOB_W +: SZJ*JOB_W] <= slot11[r];
            c21_flat_reg[r*SZJ*JOB_W +: SZJ*JOB_W] <= slot12[r];
            c22_flat_reg[r*SZJ*JOB_W +: SZJ*JOB_W] <= slot13[r];
        end
    end

    assign a11_flat = a11_flat_reg;
    assign a12_flat = a12_flat_reg;
    assign a21_flat = a21_flat_reg;
    assign a22_flat = a22_flat_reg;
    assign b11_flat = b11_flat_reg;
    assign b12_flat = b12_flat_reg;
    assign b21_flat = b21_flat_reg;
    assign b22_flat = b22_flat_reg;
    assign c11_flat = c11_flat_reg;
    assign c12_flat = c12_flat_reg;
    assign c21_flat = c21_flat_reg;
    assign c22_flat = c22_flat_reg;

endmodule
