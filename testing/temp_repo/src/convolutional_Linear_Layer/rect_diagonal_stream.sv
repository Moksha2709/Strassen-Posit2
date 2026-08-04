//`timescale 1ns/1ps


//module rect_diagonal_stream #(
//    parameter int N       = 4,                // number of rows
//    parameter int M       = 6,                // number of columns
//    parameter int DW      = 8                 // data width
//) (
//    input  logic                clk,
//    input  logic                rst,          // synchronous reset
//    input  logic                start,        // one-cycle pulse to begin
//    input  logic [DW-1:0]       matrix [0:N-1][0:M-1], // input matrix
//    output logic [DW-1:0]       out [0:M-1]  // M parallel outputs (one per column)
//);
//    // total cycles = N + M - 1, indexed 0..(N+M-2)
//    localparam int CYCLE_MAX = N + M - 2;
//    localparam int CW        = $clog2(CYCLE_MAX+1);
    
//    logic [CW-1:0]      cycle;                // which anti-diagonal we're on
//    logic               active;               // track if we're actively streaming
    
//    // Control logic: start streaming and track active state
////    logic temp = 1;
////always_ff @(posedge clk) begin
////    if (rst) begin
////        cycle <= '0;
////        active <= 1'b0;
////    end else if (start && temp) begin
////        cycle <= '0;
////        temp <= '0;
////        active <= 1'b1;
////    end else if (active) begin
////        if (cycle == CYCLE_MAX) begin
//////            active <= 1'b0;  // keep active during final cycle
////            cycle <= '0;
////            temp <= 'b1;
////        end else begin
////            cycle <= cycle + 1;
////        end
////    end
////end

//always_ff @(posedge clk) begin
//     if (rst || start) begin
//        cycle <= '0;
//        active <= 1'b1;  
//     end  
//     else if(cycle < CYCLE_MAX) begin
//     cycle <= cycle+1;
//     active <= 1;
//     end
//     else cycle <=0;
//end
         
//    // Output each anti-diagonal: for column p, row = cycle - p
//    always_comb begin
//        for (int p = 0; p < M; p++) begin
//            int row = cycle - p;
//            if (active && row >= 0 && row < N) begin
//                out[p] = matrix[row][p];
//            end else begin
//                out[p] = {DW{1'b0}};  // explicit zero assignment
//            end
//        end
//    end
    
//endmodule


`timescale 1ns/1ps

module rect_diagonal_stream #(
    parameter int N    = 3,    // # of rows
    parameter int M    = 4,    // # of columns
    parameter int DW   = 8     // data width
)(
    input  logic                clk,
    input  logic                rst,     // sync reset (active high)
    input  logic                start,   // one-cycle pulse to begin
    input  logic [DW-1:0]       matrix [0:N-1][0:M-1],
    output logic [DW-1:0]       out    [0:M-1]
);

  // # of 3-col blocks (ceil)
  localparam int G         = (M + 2) / 3;
  // total unique cycles = (N-1)+G
  localparam int CYCLE_MAX = (N - 1) + G;
  localparam int CW        = $clog2(CYCLE_MAX + 1);

  logic [CW-1:0] cycle;
  logic          running;

  // === control: start ? begin counting; wrap forever ===
  always_ff @(posedge clk) begin
    if (rst) begin
      cycle   <= 1;
      running <= 0;
    end
    else if (start) begin
      cycle   <= 1;
      running <= 1;
    end
    else if (running) begin
      // wrap
      if (cycle == CYCLE_MAX)
        cycle <= 1;
      else
        cycle <= cycle + 1;
    end
  end

  // === output logic: no more zero-gaps ===
  always_comb begin
    // default all zero
    for (int p = 0; p < M; p++)
      out[p] = '0;

    if (running) begin
      for (int p = 0; p < M; p++) begin
        int blk = p / 3;               // which block (0,1,2,…)
        int row = (cycle - 1) - blk;   // row index
        if (row >= 0 && row < N)
          out[p] = matrix[row][p];
      end
    end
  end

endmodule

