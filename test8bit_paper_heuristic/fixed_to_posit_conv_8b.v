// =============================================================================
// fixed_to_posit_conv_8b.v — Verilog
// Converts 16-bit Fixed-Point Q4.4 format back to 8-bit Posit(8,1)
// =============================================================================
`include "posit_pkg.vh"

module fixed_to_posit_conv_8b (
    input  wire [15:0] in,  // 16-bit Fixed-point (Q4.4)
    output wire [7:0]  out  // 8-bit Posit
);

    wire sign = in[15];
    wire [15:0] abs_val = sign ? (-in) : in;
    wire is_zero = (in == 16'b0);

    // Find leading one of absolute value
    reg [3:0] lead_one;
    integer i;
    always @(*) begin
        lead_one = 4'd0;
        for (i = 0; i < 16; i = i + 1) begin
            if (abs_val[i] == 1'b1)
                lead_one = i[3:0];
        end
    end

    // Scale calculation (radix point is at 4, so scale = lead_one - 4)
    wire signed [5:0] scale = $signed({2'b0, lead_one}) - 6'sd4;
    wire [15:0] normalized = abs_val << (4'd15 - lead_one);

    // Assemble decoded struct for 8-bit Posit
    wire [17:0] dec;
    assign dec[17] = sign;
    assign dec[16] = is_zero;
    assign dec[15] = 1'b0; // is_nar
    assign dec[14:8] = {scale[5], scale}; // scale sign-extended to 7 bits
    assign dec[7:0] = normalized[15:8]; // 8-bit fraction

    posit_encode #(.POSIT_WIDTH(8), .POSIT_ES(1)) enc_inst (
        .in(dec),
        .out(out)
    );

endmodule
