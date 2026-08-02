// =============================================================================
// fixed_to_posit_conv_8b.v — Verilog
// Converts 16-bit Fixed-Point Q4.4 format back to 8-bit Posit(8,1)
// =============================================================================
`include "posit_pkg.vh"

module fixed_to_posit_conv_8b (
    input  wire [23:0] in,  // 24-bit Accumulator Fixed-point (Q16.8)
    output wire [7:0]  out  // 8-bit Posit
);

    wire sign = in[23];
    wire [23:0] abs_val = sign ? (-in) : in;
    wire is_zero = (in == 24'b0);

    // Find leading one of absolute value
    reg [4:0] lead_one;
    integer i;
    always @(*) begin
        lead_one = 5'd0;
        for (i = 0; i < 24; i = i + 1) begin
            if (abs_val[i] == 1'b1)
                lead_one = i[4:0];
        end
    end

    // Scale calculation (radix point is at 16 for Q8.16 fixed-point inputs, so scale = lead_one - 16)
    wire signed [5:0] scale = $signed({1'b0, lead_one}) - 6'sd16;
    wire [23:0] normalized = abs_val << (5'd23 - lead_one);

    // Assemble decoded struct for 8-bit Posit
    wire [17:0] dec;
    assign dec[17] = sign;
    assign dec[16] = is_zero;
    assign dec[15] = 1'b0; // is_nar
    assign dec[14:8] = {scale[5], scale}; // scale sign-extended to 7 bits
    assign dec[7:0] = normalized[23:16]; // 8-bit fraction

    posit_encode #(.POSIT_WIDTH(8), .POSIT_ES(1)) enc_inst (
        .in(dec),
        .out(out)
    );

endmodule
