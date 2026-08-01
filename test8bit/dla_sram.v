// =============================================================================
// dla_sram.v — Verilog
// Parameterized synchronous three-port memory block (1 write port, 2 read ports)
// =============================================================================

module dla_sram #(
    parameter WIDTH = 128,
    parameter DEPTH = 128
) (
    input  wire                             clk,

    // Port A (Typically sideband loading / reading back)
    input  wire                             wr_en_a,
    input  wire [$clog2(DEPTH)-1:0]         addr_a,
    input  wire [WIDTH-1:0]                 data_in_a,
    output reg  [WIDTH-1:0]                 data_out_a,

    // Port B (Execution Write-only Port)
    input  wire                             wr_en_b,
    input  wire [$clog2(DEPTH)-1:0]         addr_b,
    input  wire [WIDTH-1:0]                 data_in_b,

    // Port C (Execution Read-only Port)
    input  wire                             rd_en_c,
    input  wire [$clog2(DEPTH)-1:0]         addr_c,
    output reg  [WIDTH-1:0]                 data_out_c
);

    // RAM array declaration
    reg [WIDTH-1:0] ram [0:DEPTH-1];

    integer i;
    initial begin
        for (i = 0; i < DEPTH; i = i + 1) begin
            ram[i] = {WIDTH{1'b0}};
        end
    end

    // Port A read/write
    always @(posedge clk) begin
        if (wr_en_a) begin
            ram[addr_a] <= data_in_a;
        end
        data_out_a <= ram[addr_a];
    end

    // Port B write
    always @(posedge clk) begin
        if (wr_en_b) begin
            ram[addr_b] <= data_in_b;
        end
    end

    // Port C read
    always @(posedge clk) begin
        if (rd_en_c) begin
            data_out_c <= ram[addr_c];
        end
    end

endmodule
