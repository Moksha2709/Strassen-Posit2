// =============================================================================
// pe_scale_change_tb.v
// -----------------------------------------------------------------------------
// Follow-up to pe_single_mac_tb.v. Tests scale-alignment shift logic by
// using weight = 2.0 instead of 1.0.
// =============================================================================
`timescale 1ns/1ps
`include "posit_pkg.vh"

module pe_scale_change_tb;

    reg clk;
    reg resetn;
    reg load_weight;
    reg clear_quire;
    reg shift_out;
    reg shift_load;

    reg  [35:0] posit_in_a;
    reg  [47:0] posit_in_b;
    wire [35:0] posit_out_a;
    wire [47:0] posit_out_b;

    posit_pe uut (
        .clk(clk),
        .resetn(resetn),
        .load_weight(load_weight),
        .clear_quire(clear_quire),
        .shift_out(shift_out),
        .shift_load(shift_load),
        .posit_in_a(posit_in_a),
        .posit_in_b(posit_in_b),
        .posit_out_a(posit_out_a),
        .posit_out_b(posit_out_b)
    );

    always #5 clk = ~clk;

    localparam [11:0] DEC_ONE = 12'h008; // 1.0: scale=0, mantissa=4'b1000
    localparam [11:0] DEC_TWO = 12'h018; // 2.0: scale=1, mantissa=4'b1000

    always @(posedge clk) begin
        #1;
        $display("[t=%0t] act_reg=0x%h weight_reg=0x%h | A1_mant=%d W1_mant=%d P1_exact=%d prod1=%d | accum_reg1=%0d scale_reg1=%0d",
                  $time, uut.act_reg, uut.weight_reg,
                  uut.A1_mant, uut.W1_mant, uut.P1_exact, $signed(uut.prod1),
                  $signed(uut.accum_reg1), $signed(uut.scale_reg1));
    end

    initial begin
        clk = 0;
        resetn = 0;
        load_weight = 0;
        clear_quire = 0;
        shift_out = 0;
        shift_load = 0;
        posit_in_a = 36'b0;
        posit_in_b = 48'b0;

        #10;
        resetn = 1;

        @(negedge clk);
        clear_quire = 1;
        @(negedge clk);
        clear_quire = 0;

        // ---- Load weight = 2.0 (0x018) into all 3 channels ----
        posit_in_b = {12'b0, DEC_TWO, DEC_TWO, DEC_TWO};
        load_weight = 1;
        @(negedge clk);
        load_weight = 0;
        posit_in_b = 48'b0;

        // ---- Feed activation = 1.0 (0x008) for ONE MAC cycle only ----
        posit_in_a = {DEC_ONE, DEC_ONE, DEC_ONE};
        @(negedge clk);
        posit_in_a = 36'b0;

        repeat (3) @(negedge clk);

        // ---- Shift accumulator into readout register, then shift out ----
        shift_load = 1;
        @(negedge clk);
        shift_load = 0;

        shift_out = 1;
        #1;
        $display("=============================================================");
        $display("[RESULT] raw shifted-out posit_out_b = 0x%h", posit_out_b);
        $display("[RESULT] final accum_reg1=%0d scale_reg1=%0d (channel 1, expect represents 1.0 x 2.0 = 2.0)",
                  $signed(uut.accum_reg1), $signed(uut.scale_reg1));
        $display("[RESULT] final accum_reg2=%0d scale_reg2=%0d (channel 2)",
                  $signed(uut.accum_reg2), $signed(uut.scale_reg2));
        $display("[RESULT] final accum_reg3=%0d scale_reg3=%0d (channel 3)",
                  $signed(uut.accum_reg3), $signed(uut.scale_reg3));
        $display("=============================================================");
        shift_out = 0;

        repeat (2) @(negedge clk);
        $finish;
    end

endmodule
