// =============================================================================
// fixed_to_conv_tb.v
// -----------------------------------------------------------------------------
// Testbench for fixed_to_posit_conv_8b.v
// Tests conversion of 16-bit Q4.4 fixed-point (16, 32, 8, -16) to 8-bit Posits
// =============================================================================
`timescale 1ns/1ps
`include "posit_pkg.vh"

module fixed_to_conv_tb;

    reg  [23:0] fixed_in;
    wire [7:0]  posit_out;

    fixed_to_posit_conv_8b uut (
        .in(fixed_in),
        .out(posit_out)
    );

    initial begin
        $display("=============================================================");
        $display("  fixed_to_posit_conv_8b UNIT TEST (Q4.4 Fixed -> Posit8)");
        $display("=============================================================");

        // Test 1: Q4.4 = 16 (1.0) -> Expected Posit8 = 0x40
        fixed_in = 24'd16; #10;
        $display("[INPUT: Q4.4 16 (1.0)] -> Posit8 out = 0x%02h | Expected = 0x40 (1.0)", posit_out);

        // Test 2: Q4.4 = 32 (2.0) -> Expected Posit8 = 0x50
        fixed_in = 24'd32; #10;
        $display("[INPUT: Q4.4 32 (2.0)] -> Posit8 out = 0x%02h | Expected = 0x50 (2.0)", posit_out);

        // Test 3: Q4.4 = 8 (0.5) -> Expected Posit8 = 0x30
        fixed_in = 24'd8; #10;
        $display("[INPUT: Q4.4 8 (0.5)] -> Posit8 out = 0x%02h | Expected = 0x30 (0.5)", posit_out);

        // Test 4: Q4.4 = -16 (-1.0) -> Expected Posit8 = 0xC0
        fixed_in = -24'sd16; #10;
        $display("[INPUT: Q4.4 -16 (-1.0)] -> Posit8 out = 0x%02h | Expected = 0xC0 (-1.0)", posit_out);

        $display("=============================================================");
        $finish;
    end

endmodule
