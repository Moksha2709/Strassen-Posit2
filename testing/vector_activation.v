// =============================================================================
// vector_activation.v — Verilog
// Element-wise activation unit for Posit vectors (e.g. ReLU)
// Supports 3x 8-bit channels or 6x 4-bit channels (when POSIT_WIDTH = 24)
// =============================================================================
`include "posit_pkg.vh"

module vector_activation #(
    parameter SZJ         = `DEFAULT_SZJ,
    parameter POSIT_WIDTH = `POSIT_WIDTH
) (
    input  wire                             enable,
    input  wire [SZJ*POSIT_WIDTH-1:0]       in_data,
    output wire [SZJ*POSIT_WIDTH-1:0]       out_data
);

    genvar i;
    generate
        for (i = 0; i < SZJ; i = i + 1) begin : gen_relu
            wire [POSIT_WIDTH-1:0] item_in = in_data[i*POSIT_WIDTH +: POSIT_WIDTH];
            
            // 3-way 8-bit channel ReLU
            wire [7:0] relu_8b_0 = in_data[(0*8)+7] ? 8'b0 : in_data[(0*8)+7 : (0*8)];
            wire [7:0] relu_8b_1 = in_data[(1*8)+7] ? 8'b0 : in_data[(1*8)+7 : (1*8)];
            wire [7:0] relu_8b_2 = in_data[(2*8)+7] ? 8'b0 : in_data[(2*8)+7 : (2*8)];

            assign out_data = {relu_8b_2, relu_8b_1, relu_8b_0};
        end
    endgenerate

endmodule
