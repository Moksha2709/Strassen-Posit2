// =============================================================================
// conv_to_fixed_tb.v
// -----------------------------------------------------------------------------
// Testbench for posit_to_fixed_conv_8b.v
// Tests conversion of 8-bit Posits (1.0, 2.0, 0.5, -1.0) to 16-bit Q4.4 fixed-point
// =============================================================================
`timescale 1ns/1ps
`include "posit_pkg.vh"

module conv_to_fixed_tb;

    reg  [7:0]  posit_in;
    wire [15:0] fixed_out;

    posit_to_fixed_conv_8b uut (
        .in(posit_in),
        .out(fixed_out)
    );

    initial begin
        $display("=============================================================");
        $display("  posit_to_fixed_conv_8b UNIT TEST (Posit8 -> Q4.4 Fixed)");
        $display("=============================================================");

        // Test 1: 1.0 (Posit8 encoding = 0x40) -> Expected Q4.4 = 16 (0x0010)
        posit_in = 8'h40; #10;
        $display("[INPUT: Posit 1.0 (0x40)] -> Q4.4 Fixed out = %0d (0x%04h) | Expected Q4.4 = 16 (16/16 = 1.0)",
                 $signed(fixed_out), fixed_out);

        // Test 2: 2.0 (Posit8 encoding = 0x50) -> Expected Q4.4 = 32 (0x0020)
        posit_in = 8'h50; #10;
        $display("[INPUT: Posit 2.0 (0x50)] -> Q4.4 Fixed out = %0d (0x%04h) | Expected Q4.4 = 32 (32/16 = 2.0)",
                 $signed(fixed_out), fixed_out);

        // Test 3: 0.5 (Posit8 encoding = 0x30) -> Expected Q4.4 = 8 (0x0008)
        posit_in = 8'h30; #10;
        $display("[INPUT: Posit 0.5 (0x30)] -> Q4.4 Fixed out = %0d (0x%04h) | Expected Q4.4 = 8  (8/16 = 0.5)",
                 $signed(fixed_out), fixed_out);

        // Test 4: -1.0 (Posit8 encoding = 0xC0) -> Expected Q4.4 = -16 (0xFFF0)
        posit_in = 8'hc0; #10;
        $display("[INPUT: Posit -1.0 (0xC0)] -> Q4.4 Fixed out = %0d (0x%04h) | Expected Q4.4 = -16 (-16/16 = -1.0)",
                 $signed(fixed_out), fixed_out);

        $display("=============================================================");
        $finish;
    end

endmodule
