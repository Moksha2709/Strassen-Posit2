// =============================================================================
// posit_mac_array.v — Verilog
// SZI x SZJ Grid of Processing Elements (PEs)
// Optimized to support 36-bit activation buses and 48-bit weight/readout buses.
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

    // Input vectors (flat packed, 3 channels)
    input  wire [SZI*36-1:0]                a_in,   // Activations (from west): 3x 12-bit decoded Posits per row
    input  wire [SZJ*48-1:0]                b_in,   // Weights/Shift-in (from north): 3x 16-bit formatted words per col

    // Output vector
    output wire [SZJ*48-1:0]                q       // Outputs (from south): 3x 16-bit accumulators per col
);

    // Wires for PE interconnect
    wire [35:0] conn_a [0:SZI-1][0:SZJ];
    wire [47:0] conn_b [0:SZI][0:SZJ-1];

    // Connect boundary inputs (north edge)
    genvar bj;
    generate
        for (bj = 0; bj < SZJ; bj = bj + 1) begin : north_boundary
            assign conn_b[0][bj] = b_in[bj*48 +: 48];
        end
    endgenerate

    // Instantiate PE grid
    genvar gi, gj;
    generate
        for (gi = 0; gi < SZI; gi = gi + 1) begin : row_gen
            // West boundary: connect activation input
            assign conn_a[gi][0] = a_in[gi*36 +: 36];

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
            assign q[sj*48 +: 48] = conn_b[SZI][sj];
        end
    endgenerate

endmodule
