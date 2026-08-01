// =============================================================================
// posit_mac_array.v — Verilog
// SZI x SZJ Grid of Processing Elements (PEs)
// Converted to support 72-bit activation buses and 96-bit weight/readout buses.
// =============================================================================
`include "posit_pkg.vh"
`include "strassen_pkg.vh"

module posit_mac_array #(
    parameter SZI         = `DEFAULT_SZI,
    parameter SZJ         = `DEFAULT_SZJ
) (
    input  wire                             clk,
    input  wire                             resetn,

    // Control signals
    input  wire                             load_weight,
    input  wire                             clear_quire,
    input  wire                             shift_out,
    input  wire                             shift_load,

    // Input vectors (flat packed)
    input  wire [SZI*72-1:0]                a_in,   // Activations (from west): 6x 12-bit decoded Posits per row
    input  wire [SZJ*96-1:0]                b_in,   // Weights/Shift-in (from north): 6x 16-bit or 12-bit per col

    // Output vector
    output wire [SZJ*96-1:0]                q       // Outputs (from south): 6x 16-bit accumulators per col
);

    // Wires for PE interconnect
    wire [71:0] conn_a [0:SZI-1][0:SZJ];
    wire [95:0] conn_b [0:SZI][0:SZJ-1];

    // Connect boundary inputs (north edge)
    genvar bj;
    generate
        for (bj = 0; bj < SZJ; bj = bj + 1) begin : north_boundary
            assign conn_b[0][bj] = b_in[bj*96 +: 96];
        end
    endgenerate

    // Instantiate PE grid
    genvar gi, gj;
    generate
        for (gi = 0; gi < SZI; gi = gi + 1) begin : row_gen
            // West boundary: connect activation input
            assign conn_a[gi][0] = a_in[gi*72 +: 72];

            for (gj = 0; gj < SZJ; gj = gj + 1) begin : col_gen
                posit_pe pe_inst (
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
            assign q[sj*96 +: 96] = conn_b[SZI][sj];
        end
    endgenerate

endmodule
