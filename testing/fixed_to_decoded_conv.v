// =============================================================================
// fixed_to_decoded_conv.v — Verilog
// Converts 24-bit Fixed-Point (Q8.16) to 12-bit Decoded Posit struct
// Struct format: [sign(11), is_zero(10), scale(9:4), mantissa(3:0)]
// =============================================================================
`include "posit_pkg.vh"

module fixed_to_decoded_conv (
    input  wire [23:0] in,   // 24-bit Fixed-point (Q8.16)
    output reg  [11:0] out   // 12-bit decoded struct
);

    wire sign = in[23];
    wire [23:0] abs_val = sign ? (-in) : in;
    wire is_zero = (in == 24'b0);

    reg [4:0] lead_one;
    integer i;
    always @(*) begin
        lead_one = 5'd0;
        for (i = 0; i < 24; i = i + 1) begin
            if (abs_val[i] == 1'b1)
                lead_one = i[4:0];
        end
    end

    wire signed [5:0] scale = $signed({1'b0, lead_one}) - 6'sd16;
    wire [23:0] normalized = abs_val << (5'd23 - lead_one);

    always @(*) begin
        out[11]  = sign;
        out[10]  = is_zero;
        if (is_zero) begin
            out[9:4] = 6'b0;
            out[3:0] = 4'b0;
        end else begin
            out[9:4] = scale;
            out[3:0] = normalized[23:20]; // 4-bit mantissa including hidden 1
        end
    end

endmodule
