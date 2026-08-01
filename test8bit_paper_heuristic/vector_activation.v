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
    input  wire                             simd_mode,
    input  wire [SZJ*POSIT_WIDTH-1:0]       in_data,
    output wire [SZJ*POSIT_WIDTH-1:0]       out_data
);

    genvar i;
    generate
        for (i = 0; i < SZJ; i = i + 1) begin : gen_relu
            wire [POSIT_WIDTH-1:0] item_in = in_data[i*POSIT_WIDTH +: POSIT_WIDTH];
            
            // 3-way 8-bit channel ReLU
            wire [7:0] relu_8b_0 = (enable && item_in[7])  ? 8'b0 : item_in[7:0];
            wire [7:0] relu_8b_1 = (enable && item_in[15]) ? 8'b0 : item_in[15:8];
            wire [7:0] relu_8b_2 = (enable && item_in[23]) ? 8'b0 : item_in[23:16];

            // 6-way 4-bit channel SIMD ReLU
            wire [3:0] relu_4b_0 = (enable && item_in[3])  ? 4'b0 : item_in[3:0];
            wire [3:0] relu_4b_1 = (enable && item_in[7])  ? 4'b0 : item_in[7:4];
            wire [3:0] relu_4b_2 = (enable && item_in[11]) ? 4'b0 : item_in[11:8];
            wire [3:0] relu_4b_3 = (enable && item_in[15]) ? 4'b0 : item_in[15:12];
            wire [3:0] relu_4b_4 = (enable && item_in[19]) ? 4'b0 : item_in[19:16];
            wire [3:0] relu_4b_5 = (enable && item_in[23]) ? 4'b0 : item_in[23:20];

            assign out_data[i*POSIT_WIDTH +: POSIT_WIDTH] = 
                simd_mode ? {relu_4b_5, relu_4b_4, relu_4b_3, relu_4b_2, relu_4b_1, relu_4b_0} : 
                {relu_8b_2, relu_8b_1, relu_8b_0};
        end
    endgenerate

endmodule
