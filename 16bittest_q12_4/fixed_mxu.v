// =============================================================================
// fixed_mxu.v — Verilog
// Matrix Execution Unit: activation/weight skewing + fixed MAC array wrapper
// =============================================================================
`include "fixed_pkg.vh"
`include "strassen_pkg.vh"

module fixed_mxu #(
    parameter SZI         = `DEFAULT_SZI,
    parameter SZJ         = `DEFAULT_SZJ,
    parameter DATA_WIDTH  = `DATA_WIDTH,
    parameter FRAC_WIDTH  = `FRAC_WIDTH
) (
    input  wire                             clk,
    input  wire                             resetn,

    // Control inputs from Strassen Controller
    input  wire                             load_weight,
    input  wire                             clear_quire,
    input  wire                             shift_out,
    input  wire                             shift_load,

    // Vectors
    input  wire [SZI*DATA_WIDTH-1:0]        a,  // Activations (unskewed)
    input  wire [SZJ*DATA_WIDTH-1:0]        b,  // Weights / Shift-in
    output wire [SZJ*DATA_WIDTH-1:0]        c   // Outputs
);

    localparam DW = DATA_WIDTH;

    // --- Systolic activation skewing (delay row i by i cycles) ---
    wire [SZI*DW-1:0] a_skewed;

    genvar gi;
    generate
        for (gi = 0; gi < SZI; gi = gi + 1) begin : skew_gen
            if (gi == 0) begin : no_delay
                assign a_skewed[gi*DW +: DW] = a[gi*DW +: DW];
            end else begin : with_delay
                reg [gi*DW-1:0] shift_reg;

                always @(posedge clk or negedge resetn) begin
                    if (!resetn) begin
                        shift_reg <= {(gi*DW){1'b0}};
                    end else begin
                        if (gi == 1) begin
                            shift_reg[DW-1:0] <= a[gi*DW +: DW];
                        end else begin
                            shift_reg <= {shift_reg[(gi-1)*DW-1:0], a[gi*DW +: DW]};
                        end
                    end
                end

                assign a_skewed[gi*DW +: DW] = shift_reg[gi*DW-1 -: DW];
            end
        end
    endgenerate

    // --- Systolic weight skewing (delay col gj by gj cycles) ---
    wire [SZJ*DW-1:0] b_skewed;

    genvar gj;
    generate
        for (gj = 0; gj < SZJ; gj = gj + 1) begin : skew_b_gen
            if (gj == 0) begin : no_delay_b
                assign b_skewed[gj*DW +: DW] = b[gj*DW +: DW];
            end else begin : with_delay_b
                reg [gj*DW-1:0] shift_reg_b;

                always @(posedge clk or negedge resetn) begin
                    if (!resetn) begin
                        shift_reg_b <= {(gj*DW){1'b0}};
                    end else begin
                        if (gj == 1) begin
                            shift_reg_b[DW-1:0] <= b[gj*DW +: DW];
                        end else begin
                            shift_reg_b <= {shift_reg_b[(gj-1)*DW-1:0], b[gj*DW +: DW]};
                        end
                    end
                end

                assign b_skewed[gj*DW +: DW] = shift_reg_b[gj*DW-1 -: DW];
            end
        end
    endgenerate

    // --- MAC Array ---
    fixed_mac_array #(
        .SZI(SZI), .SZJ(SZJ),
        .DATA_WIDTH(DW), .FRAC_WIDTH(FRAC_WIDTH)
    ) mac_array_inst (
        .clk(clk), .resetn(resetn),
        .load_weight(load_weight),
        .clear_quire(clear_quire),
        .shift_out(shift_out),
        .shift_load(shift_load),
        .a_in(a_skewed),
        .b_in(b_skewed),
        .q(c)
    );

endmodule
