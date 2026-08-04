// =============================================================================
// vector_activation.v — Verilog
// Element-wise activation unit for fixed-point vectors (ReLU)
// Each element is an 8-bit signed fixed-point value; ReLU zeroes negative values.
// =============================================================================
`include "fixed_pkg.vh"

module vector_activation #(
    parameter SZJ        = 8,
    parameter DATA_WIDTH = `DATA_WIDTH
) (
    input  wire                             enable,
    input  wire [SZJ*DATA_WIDTH-1:0]        in_data,
    output wire [SZJ*DATA_WIDTH-1:0]        out_data
);

    genvar i;
    generate
        for (i = 0; i < SZJ; i = i + 1) begin : gen_relu
            wire [DATA_WIDTH-1:0] item_in = in_data[i*DATA_WIDTH +: DATA_WIDTH];

            // Signed ReLU: if enable and MSB (sign bit) is 1 (negative), output zero
            assign out_data[i*DATA_WIDTH +: DATA_WIDTH] =
                (enable && item_in[DATA_WIDTH-1]) ? {DATA_WIDTH{1'b0}} : item_in;
        end
    endgenerate

endmodule
