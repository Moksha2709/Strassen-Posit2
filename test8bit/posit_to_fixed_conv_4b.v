// =============================================================================
// posit_to_fixed_conv_4b.v — Verilog
// Decodes a 4-bit Posit (POSIT(4,0)) to 16-bit Q4.4 signed fixed-point
// Uses a mathematically exact lookup table for high performance and low area.
// =============================================================================
`include "posit_pkg.vh"

module posit_to_fixed_conv_4b (
    input  wire [3:0]  in,  // 4-bit Posit
    output reg  [15:0] out  // 16-bit Fixed-point (Q4.4)
);

    always @(*) begin
        case (in)
            4'd0:  out = 16'sd0;     // 0.0
            4'd1:  out = 16'sd4;     // 0.25 (0.25 * 16 = 4)
            4'd2:  out = 16'sd8;     // 0.5  (0.5 * 16 = 8)
            4'd3:  out = 16'sd12;    // 0.75 (0.75 * 16 = 12)
            4'd4:  out = 16'sd16;    // 1.0  (1.0 * 16 = 16)
            4'd5:  out = 16'sd24;    // 1.5  (1.5 * 16 = 24)
            4'd6:  out = 16'sd32;    // 2.0  (2.0 * 16 = 32)
            4'd7:  out = 16'sd64;    // 4.0  (4.0 * 16 = 64)
            4'd8:  out = 16'sd0;     // NaR (handled as 0.0)
            4'd9:  out = -16'sd64;   // -4.0
            4'd10: out = -16'sd32;   // -2.0
            4'd11: out = -16'sd24;   // -1.5
            4'd12: out = -16'sd16;   // -1.0
            4'd13: out = -16'sd12;   // -0.75
            4'd14: out = -16'sd8;    // -0.5
            4'd15: out = -16'sd4;    // -0.25
        endcase
    end
endmodule
