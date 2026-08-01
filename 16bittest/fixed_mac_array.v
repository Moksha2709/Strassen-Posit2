// =============================================================================
// fixed_mac_array.v — Verilog
// SZI x SZJ grid of Fixed-Point Processing Elements
// =============================================================================
`include "fixed_pkg.vh"
`include "strassen_pkg.vh"

module fixed_mac_array #(
    parameter SZI         = `DEFAULT_SZI,
    parameter SZJ         = `DEFAULT_SZJ,
    parameter DATA_WIDTH  = `DATA_WIDTH,
    parameter FRAC_WIDTH  = `FRAC_WIDTH
) (
    input  wire                             clk,
    input  wire                             resetn,

    // Control signals
    input  wire                             load_weight,
    input  wire                             clear_quire,
    input  wire                             shift_out,
    input  wire                             shift_load,

    // Input vectors
    input  wire [SZI*DATA_WIDTH-1:0]        a_in,   // Activations from west
    input  wire [SZJ*DATA_WIDTH-1:0]        b_in,   // Weights/Shift-in from north

    // Output vector
    output wire [SZJ*DATA_WIDTH-1:0]        q       // Outputs from south
);

    localparam DW = DATA_WIDTH;

    // Wires for PE interconnect
    wire [DW-1:0] conn_a [0:SZI-1][0:SZJ];
    wire [DW-1:0] conn_b [0:SZI][0:SZJ-1];

    // Connect boundary inputs (north edge)
    genvar bj;
    generate
        for (bj = 0; bj < SZJ; bj = bj + 1) begin : north_boundary
            assign conn_b[0][bj] = b_in[bj*DW +: DW];
        end
    endgenerate

    // Instantiate PE grid
    genvar gi, gj;
    generate
        for (gi = 0; gi < SZI; gi = gi + 1) begin : row_gen
            // West boundary: connect activation input
            assign conn_a[gi][0] = a_in[gi*DW +: DW];

            for (gj = 0; gj < SZJ; gj = gj + 1) begin : col_gen
                fixed_pe #(.DATA_WIDTH(DW), .FRAC_WIDTH(FRAC_WIDTH))
                    pe_inst (
                        .clk(clk),
                        .resetn(resetn),
                        .load_weight(load_weight),
                        .clear_quire(clear_quire),
                        .shift_out(shift_out),
                        .shift_load(shift_load),
                        .posit_in_a(conn_a[gi][gj]),
                        .posit_in_b(conn_b[gi][gj]),
                        .posit_out_a(conn_a[gi][gj+1]),
                        .posit_out_b(conn_b[gi+1][gj])
                    );
            end
        end
    endgenerate

    // Connect boundary outputs (south edge)
    genvar sj;
    generate
        for (sj = 0; sj < SZJ; sj = sj + 1) begin : south_boundary
            assign q[sj*DW +: DW] = conn_b[SZI][sj];
        end
    endgenerate

endmodule
