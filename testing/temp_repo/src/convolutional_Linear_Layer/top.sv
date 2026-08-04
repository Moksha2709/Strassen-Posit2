//`timescale 1ns/1ps

//module top#(
//    parameter int N       = 4,                // number of rows
//    parameter int M       = 6, 
//    parameter int P       = 6,               // number of columns
//    parameter int DW      = 8  
//)(
//    input clk,
//    input  logic                rst, 
//    input logic startLinearLayer,        
//    input  logic [DW-1:0]       a [0:N-1][0:M-1],
//    input  logic [DW-1:0]       b [0:M-1][0:P-1],
//    output logic [DW-1:0] column_mult,
//    output logic done
    
//);
//    localparam int CYCLE_MAX = N + M - 2;
//    localparam int CW        = $clog2(CYCLE_MAX+1);
//    logic [CW-1:0]      cycle;               
//    logic [DW-1:0]       a_arrange [0:M-1];
//    logic [DW-1:0]       b_arrange [0:M-1];
//    logic [$clog2(P)-1:0] col_index = 1;
    
////    logic start = startLinearLayer; 
//    rect_diagonal_stream #(
//        .N(N),
//        .M(M),
//        .DW(DW),
//        .P(P)
//    ) dut (
//        .clk(clk),
//        .rst(rst),
//        .start(startLinearLayer),
//        .matrix(a),
//        .out(a_arrange)
//    );
    
//        column_PE #(
//        .N(N),
//        .M(M),
//        .DW(DW)
//    ) columnPE (
//        .clk(clk),
//        .a_arrange(a_arrange),
//        .b_arrange(b_arrange),
//        .column_mult(column_mult)
//    );
    
    
    
    
//always_ff @(posedge clk) begin
//     if (rst || startLinearLayer) begin
//        cycle <= '0; 
//        for (int i = 0; i < M; i++) begin
//            b_arrange[i] <= b[i][0];
//        end
//     end  
//     else if(cycle < CYCLE_MAX) begin
//     cycle <= cycle+1;
//     end
//     else begin
//        cycle <=0;
//        for (int i = 0; i < M; i++) begin
//            b_arrange[i] <= b[i][col_index];
//        end

//        if (col_index == P - 1)
//            done <= 1;
//        else
//            col_index <= col_index + 1;
//    end
//end
    

//endmodule





`timescale 1ns/1ps

module top#(
    parameter int N       = 576,                // number of rows
    parameter int M       = 25, 
    parameter int P       = 1,               // number of columns
    parameter int DW      = 8,
    parameter int N_in    = 576,  
    parameter int M_in    = 25 ,
    parameter es = 1
)(
    input clk,
    input  logic                rst, 
    input logic startLinearLayer,  
//    input logic mode,      
    input  logic [DW-1:0]       a [0:N_in-1][0:M_in-1],
    input  logic [DW-1:0]       b [0:M_in-1][0:P-1],
    output logic [DW-1:0] column_mult,
    output logic done,
    output logic [DW-1:0] matrix_out [0:N-1][0:P-1],
    output logic done_new
    
);
    logic          running;
    logic mode = 0;
    localparam int div_half = (M_in / M);
    localparam int G         = (M + 2) / 3;
    localparam int CYCLE_MAX = (N - 1) + G;
    localparam int CW        = $clog2(CYCLE_MAX+1);
    logic [CW-1:0]      cycle;               
    logic [DW-1:0]       a_arrange [0:M-1];
    logic [DW-1:0]       b_arrange [0:M-1];
    logic [$clog2(P):0] col_index;
    
//    logic [DW-1:0] matrix_out [0:N-1][0:P-1];
    logic req;                      
    logic [$clog2(N)-1:0] i_row;
    logic [$clog2(P):0] j_col;
    logic [DW-1:0] initial_cin;
    logic [$clog2(div_half):0] counter_half;
    
    
    logic [DW-1:0] a_half [0:N-1][0:M-1];
    logic [DW-1:0] b_half [0:M-1][0:P-1];
    
//    logic start = startLinearLayer; 
    rect_diagonal_stream #(
        .N(N),
        .M(M),
        .DW(DW)
    ) dut (
        .clk(clk),
        .rst(rst),
        .start(startLinearLayer || done_new),
        .matrix(a_half),
        .out(a_arrange)
    );
    
        column_PE #(
        .N(N),
        .M(M),
        .DW(DW),
        .es(es)
    ) columnPE (
        .clk(clk),
        .rst(rst),
        .a_arrange(a_arrange),
        .b_arrange(b_arrange),
         .initial_cin(initial_cin),
        .column_mult(column_mult)
    );
    
    
    
    
//always_ff @(posedge clk) begin
//     if (rst || startLinearLayer) begin
//        cycle <= '0; 
//        for (int i = 0; i < M; i++) begin
//            b_arrange[i] <= b[i][0];
//        end
//     end  
//     else if(cycle < CYCLE_MAX) begin
//     cycle <= cycle+1;
//     end
//     else begin
//        cycle <=0;
//        for (int i = 0; i < M; i++) begin
//            b_arrange[i] <= b[i][col_index];
//        end

//        if (col_index == P - 1)
//            done <= 1;
//        else
//            col_index <= col_index + 1;
//    end
//end



//    always_ff @(posedge clk) begin
//        if ((counter_half <= div_half)) begin
//            for (int i = 0; i < N; i++) begin
//                for (int j = (counter_half - 1) * M; j < M*counter_half; j++) begin
//                    a_half[i][j] <= a[i][j];
//                end
//            end
    
//            for (int i = (counter_half - 1) * M; i < M*counter_half; i++) begin
//                for (int j = 0; j < P; j++) begin
//                    b_half[i][j] <= b[i][j];
//                end
//            end
//        end
//    end

always_ff @(posedge clk) begin
    if (counter_half <= div_half) begin
        int a_offset, b_offset;
        a_offset = (counter_half - 1) * M;
        b_offset = (counter_half - 1) * M;

        for (int i = 0; i < N; i++) begin
            for (int j = 0; j < M; j++) begin
                a_half[i][j] = a[i][j + a_offset];
            end
        end

        for (int i = 0; i < M; i++) begin
            for (int j = 0; j < P; j++) begin
                b_half[i][j] = b[i + b_offset][j];
            end
        end
    end
end






    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            counter_half <= 1;
        end else if (done) begin
            if (counter_half < div_half ) begin
                counter_half <= counter_half + 1;
            end else begin
                counter_half <= 1; // wrap around
            end
        end
    end





//  always_ff @(posedge clk) begin
//    if (rst) begin
//      cycle   <= 1;
//      running <= 0;
//      for (int i = 0; i < M; i++) begin
//            b_arrange[i] <= b_half[i][0];
//        end
//      for (int i = 0; i < N; i++) begin
//            for (int j = 0; j < P; j++) begin
//                matrix_out[i][j] <= 'd0;
//            end
//        end
        
        
        
//    end
//    else if (startLinearLayer || done_new) begin
//      cycle   <= 1;
//      running <= 1;
//      i_row <=0;
//      j_col <=0;
//      col_index <= 1;
//      for (int i = 0; i < M; i++) begin
//            b_arrange[i] <= b_half[i][0];
//        end
//      if(mode)  
//        initial_cin <= matrix_out[0][0];
//      else initial_cin <= 0;
//    end
//    else if (running && !done) begin
//      // wrap
//      if (cycle == CYCLE_MAX) begin
//        cycle <= 1;
//        for (int i = 0; i < M; i++) begin
//            b_arrange[i] <= b_half[i][col_index];
//        end
        
//        if(mode)
//            initial_cin <= matrix_out[0][col_index];
//        else initial_cin <= 0;
////        if (col_index == P - 1)
////            done <= 1;
////        else
//            col_index <= col_index + 1;
//      end
        
//      else begin
//        cycle <= cycle + 1;   
//      end
//    end
//  end
    
    
//    always_ff @(posedge clk) begin
//      if (req) begin
//        if (i_row < N) begin
//          matrix_out[i_row][j_col] <= column_mult;
//          i_row <= i_row + 1;
//          if (i_row + 1 == N) begin
//            if(j_col + 1 != P) j_col <= j_col + 1;
//            i_row <= 0; 
//          end
//        end
//      end
//    end
    
    always_ff @(posedge clk) begin
  if (rst) begin
    cycle   <= 1;
    running <= 0;
    i_row   <= 0;
    j_col   <= 0;
    col_index <= 0;

    for (int i = 0; i < M; i++) begin
      b_arrange[i] <= b_half[i][0];
    end

    for (int i = 0; i < N; i++) begin
      for (int j = 0; j < P; j++) begin
        matrix_out[i][j] <= 'd0;
      end
    end

  end else if (startLinearLayer || done_new) begin
    cycle   <= 1;
    running <= 1;
    i_row   <= 0;
    j_col   <= 0;
    col_index <= 1;

    for (int i = 0; i < M; i++) begin
      b_arrange[i] <= b_half[i][0];
    end

    if (mode)
      initial_cin <= matrix_out[0][0];
    else
      initial_cin <= 0;

  end else if (running && !done) begin
    // cycle wrapping logic
    if (cycle == CYCLE_MAX) begin
      cycle <= 1;

      for (int i = 0; i < M; i++) begin
        b_arrange[i] <= b_half[i][col_index];
      end

      if (mode)
        initial_cin <= matrix_out[0][col_index];
      else
        initial_cin <= 0;

      col_index <= col_index + 1;
    end else begin
      cycle <= cycle + 1;
    end
  end

  // Write result if req is high
  if (req) begin
    if (i_row < N) begin
      matrix_out[i_row][j_col] <= column_mult;
      i_row <= i_row + 1;

      if (i_row + 1 == N) begin
        if (j_col + 1 != P)
          j_col <= j_col + 1;
        i_row <= 0;
      end
    end
  end
end

    
    always_ff @(posedge clk) begin
       if(cycle >= G && cycle <= CYCLE_MAX) begin
            req <= 'd1;
            if(j_col == P-1 && cycle == CYCLE_MAX) done<=1;
        end
        else begin
         req <= 'd0;
         done <= 'd0;
        end       
    end     
    
    
    always_ff @(posedge clk) begin
        done_new <= done;
    end
    
//    always_ff @(posedge clk) begin

//        if(done_new) begin
////        startLinearLayer <= 1;
//        end
//    end
        
 
    
    

endmodule