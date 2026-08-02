`timescale 1ns / 1ps

module avgpool_tb;

    parameter N   = 8;
    parameter ROW = 24;
    parameter COL = 24;
    parameter ES  = 1;

    // Input and output vectors
    logic [ROW*COL*N-1:0] image_i;
    logic [(N*(ROW/2)*(COL/2))-1:0] result_o;
    logic clk;
    logic rst;
    logic start;
    logic done;
    logic [N-1:0] unpacked [ROW/2-1:0][COL/2-1:0];
    // Instantiate the DUT
    avgpool #(
        .N(N),
        .ROW(ROW),
        .COL(COL),
        .ES(ES)
    ) dut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .image_i(image_i),
        .result_o(result_o),
        .done(done)
    );

    // 8x8 signed int matrix (initialize with simple values)
    logic signed [7:0] image_matrix [0:ROW-1][0:COL-1];

    // Task to flatten the matrix into the input vector
    task flatten_input();
        integer i, j;
        for (i = 0; i < ROW; i = i + 1) begin
            for (j = 0; j < COL; j = j + 1) begin
                image_i[(i*COL + j)*N +: N] = image_matrix[i][j];
            end
        end
    endtask

    // Task to print output
    task print_output();
        integer i, j;
        logic signed [7:0] temp;
        $display("\nOutput of avgpool:");
        for (i = 0; i < ROW/2; i = i + 1) begin
            for (j = 0; j < COL; j = j + 1) begin
                temp = result_o[(i*COL + j)*N +: N];
                $write("%0b ", temp);
            end
            $display("");
        end
    endtask
    
    for(genvar i = 0; i < ROW/2; i++) begin
        for(genvar j = 0; j < COL/2; j++) begin
            assign unpacked[i][j] = result_o[(i*COL/2 + j)*N +: N]; 
        end
    end
    int fd;
    string filename = "unpacked_flat_binary.txt";
    initial clk <= 0;
    always #5 clk <= ~clk;

    // Initial block
    initial begin
        integer i, j;
        rst <= 1'b1;
        start <= 1'b0;
        @(posedge clk);
        rst <= 1'b0;

        // Initialize the 8x8 image with simple pattern
        for (i = 0; i < ROW; i = i + 1) begin
            for (j = 0; j < COL; j = j + 1) begin
                image_matrix[i][j] = '0;  // values 0 to 63
            end
        end

        flatten_input();  // Convert to flat input
        start <= 1'b1;
        wait(done);
        start <= 1'b0;
        print_output();  // Print results
        @(posedge clk);
        @(posedge clk);
        // Posit encoded Toeplitz matrix (576x25) from image
        // Posit encoded Toeplitz matrix (576x25) from image
        // Posit encoded Toeplitz matrix (576x25) from image
        image_matrix[0][0] = 8'b00000000;
        image_matrix[0][1] = 8'b00000000;
        image_matrix[0][2] = 8'b00000000;
        image_matrix[0][3] = 8'b00000000;
        image_matrix[0][4] = 8'b00000000;
        image_matrix[0][5] = 8'b00000000;
        image_matrix[0][6] = 8'b00000000;
        image_matrix[0][7] = 8'b00000000;
        image_matrix[0][8] = 8'b00000000;
        image_matrix[0][9] = 8'b00000000;
        image_matrix[0][10] = 8'b00000000;
        image_matrix[0][11] = 8'b00000000;
        image_matrix[0][12] = 8'b00000000;
        image_matrix[0][13] = 8'b00000000;
        image_matrix[0][14] = 8'b00000000;
        image_matrix[0][15] = 8'b00000000;
        image_matrix[0][16] = 8'b00000000;
        image_matrix[0][17] = 8'b00000000;
        image_matrix[0][18] = 8'b00000000;
        image_matrix[0][19] = 8'b00000000;
        image_matrix[0][20] = 8'b00000000;
        image_matrix[0][21] = 8'b00000000;
        image_matrix[0][22] = 8'b00000000;
        image_matrix[0][23] = 8'b00000000;
        image_matrix[1][0] = 8'b00000000;
        image_matrix[1][1] = 8'b00000000;
        image_matrix[1][2] = 8'b00000000;
        image_matrix[1][3] = 8'b00000000;
        image_matrix[1][4] = 8'b00000000;
        image_matrix[1][5] = 8'b00000000;
        image_matrix[1][6] = 8'b00000000;
        image_matrix[1][7] = 8'b00000000;
        image_matrix[1][8] = 8'b00000000;
        image_matrix[1][9] = 8'b00000000;
        image_matrix[1][10] = 8'b00000000;
        image_matrix[1][11] = 8'b00000000;
        image_matrix[1][12] = 8'b00000000;
        image_matrix[1][13] = 8'b00000000;
        image_matrix[1][14] = 8'b00000000;
        image_matrix[1][15] = 8'b00000000;
        image_matrix[1][16] = 8'b00000000;
        image_matrix[1][17] = 8'b00000000;
        image_matrix[1][18] = 8'b00000000;
        image_matrix[1][19] = 8'b00000000;
        image_matrix[1][20] = 8'b00000000;
        image_matrix[1][21] = 8'b00000000;
        image_matrix[1][22] = 8'b00000000;
        image_matrix[1][23] = 8'b00000000;
        image_matrix[2][0] = 8'b00000000;
        image_matrix[2][1] = 8'b00000000;
        image_matrix[2][2] = 8'b00000000;
        image_matrix[2][3] = 8'b00000000;
        image_matrix[2][4] = 8'b00000000;
        image_matrix[2][5] = 8'b00000000;
        image_matrix[2][6] = 8'b00000000;
        image_matrix[2][7] = 8'b00000000;
        image_matrix[2][8] = 8'b00000000;
        image_matrix[2][9] = 8'b00000000;
        image_matrix[2][10] = 8'b00000000;
        image_matrix[2][11] = 8'b00000000;
        image_matrix[2][12] = 8'b00000000;
        image_matrix[2][13] = 8'b00000000;
        image_matrix[2][14] = 8'b00000000;
        image_matrix[2][15] = 8'b00000000;
        image_matrix[2][16] = 8'b00000000;
        image_matrix[2][17] = 8'b00000000;
        image_matrix[2][18] = 8'b00000000;
        image_matrix[2][19] = 8'b00000000;
        image_matrix[2][20] = 8'b00000000;
        image_matrix[2][21] = 8'b00000000;
        image_matrix[2][22] = 8'b00000000;
        image_matrix[2][23] = 8'b00000000;
        image_matrix[3][0] = 8'b00000000;
        image_matrix[3][1] = 8'b00000000;
        image_matrix[3][2] = 8'b00010101;
        image_matrix[3][3] = 8'b00101000;
        image_matrix[3][4] = 8'b00100000;
        image_matrix[3][5] = 8'b00100011;
        image_matrix[3][6] = 8'b00011110;
        image_matrix[3][7] = 8'b00010100;
        image_matrix[3][8] = 8'b00001111;
        image_matrix[3][9] = 8'b00000000;
        image_matrix[3][10] = 8'b00000000;
        image_matrix[3][11] = 8'b00000000;
        image_matrix[3][12] = 8'b00000000;
        image_matrix[3][13] = 8'b00000000;
        image_matrix[3][14] = 8'b00000000;
        image_matrix[3][15] = 8'b00000000;
        image_matrix[3][16] = 8'b00000000;
        image_matrix[3][17] = 8'b00000000;
        image_matrix[3][18] = 8'b00000000;
        image_matrix[3][19] = 8'b00000000;
        image_matrix[3][20] = 8'b00000000;
        image_matrix[3][21] = 8'b00000000;
        image_matrix[3][22] = 8'b00000000;
        image_matrix[3][23] = 8'b00000000;
        image_matrix[4][0] = 8'b00000000;
        image_matrix[4][1] = 8'b00000000;
        image_matrix[4][2] = 8'b00110111;
        image_matrix[4][3] = 8'b01000101;
        image_matrix[4][4] = 8'b01001010;
        image_matrix[4][5] = 8'b01010101;
        image_matrix[4][6] = 8'b01010101;
        image_matrix[4][7] = 8'b01010010;
        image_matrix[4][8] = 8'b01001001;
        image_matrix[4][9] = 8'b01000001;
        image_matrix[4][10] = 8'b00111001;
        image_matrix[4][11] = 8'b00110010;
        image_matrix[4][12] = 8'b00110010;
        image_matrix[4][13] = 8'b00110010;
        image_matrix[4][14] = 8'b00110010;
        image_matrix[4][15] = 8'b00110010;
        image_matrix[4][16] = 8'b00101111;
        image_matrix[4][17] = 8'b00011011;
        image_matrix[4][18] = 8'b00001110;
        image_matrix[4][19] = 8'b00010011;
        image_matrix[4][20] = 8'b00000000;
        image_matrix[4][21] = 8'b00000000;
        image_matrix[4][22] = 8'b00000000;
        image_matrix[4][23] = 8'b00000000;
        image_matrix[5][0] = 8'b00000000;
        image_matrix[5][1] = 8'b00000000;
        image_matrix[5][2] = 8'b00110010;
        image_matrix[5][3] = 8'b01000010;
        image_matrix[5][4] = 8'b01010011;
        image_matrix[5][5] = 8'b01011101;
        image_matrix[5][6] = 8'b01011111;
        image_matrix[5][7] = 8'b01011110;
        image_matrix[5][8] = 8'b01011100;
        image_matrix[5][9] = 8'b01011011;
        image_matrix[5][10] = 8'b01011011;
        image_matrix[5][11] = 8'b01011011;
        image_matrix[5][12] = 8'b01011011;
        image_matrix[5][13] = 8'b01011100;
        image_matrix[5][14] = 8'b01011011;
        image_matrix[5][15] = 8'b01011100;
        image_matrix[5][16] = 8'b01011011;
        image_matrix[5][17] = 8'b01010101;
        image_matrix[5][18] = 8'b01001100;
        image_matrix[5][19] = 8'b01000001;
        image_matrix[5][20] = 8'b00100110;
        image_matrix[5][21] = 8'b00000000;
        image_matrix[5][22] = 8'b00000000;
        image_matrix[5][23] = 8'b00000000;
        image_matrix[6][0] = 8'b00000000;
        image_matrix[6][1] = 8'b00000000;
        image_matrix[6][2] = 8'b00000000;
        image_matrix[6][3] = 8'b00000000;
        image_matrix[6][4] = 8'b00100100;
        image_matrix[6][5] = 8'b00000000;
        image_matrix[6][6] = 8'b00000000;
        image_matrix[6][7] = 8'b00010101;
        image_matrix[6][8] = 8'b01000101;
        image_matrix[6][9] = 8'b01001111;
        image_matrix[6][10] = 8'b01010101;
        image_matrix[6][11] = 8'b01011000;
        image_matrix[6][12] = 8'b01011000;
        image_matrix[6][13] = 8'b01011010;
        image_matrix[6][14] = 8'b01011000;
        image_matrix[6][15] = 8'b01011101;
        image_matrix[6][16] = 8'b01011110;
        image_matrix[6][17] = 8'b01011000;
        image_matrix[6][18] = 8'b01010011;
        image_matrix[6][19] = 8'b01000101;
        image_matrix[6][20] = 8'b00011101;
        image_matrix[6][21] = 8'b00000000;
        image_matrix[6][22] = 8'b00000000;
        image_matrix[6][23] = 8'b00000000;
        image_matrix[7][0] = 8'b00000000;
        image_matrix[7][1] = 8'b00000000;
        image_matrix[7][2] = 8'b00000000;
        image_matrix[7][3] = 8'b00000000;
        image_matrix[7][4] = 8'b00000000;
        image_matrix[7][5] = 8'b00000000;
        image_matrix[7][6] = 8'b00000000;
        image_matrix[7][7] = 8'b00000000;
        image_matrix[7][8] = 8'b00000000;
        image_matrix[7][9] = 8'b00000000;
        image_matrix[7][10] = 8'b00000000;
        image_matrix[7][11] = 8'b00000000;
        image_matrix[7][12] = 8'b00000000;
        image_matrix[7][13] = 8'b00000000;
        image_matrix[7][14] = 8'b00000000;
        image_matrix[7][15] = 8'b00000000;
        image_matrix[7][16] = 8'b00000000;
        image_matrix[7][17] = 8'b00010100;
        image_matrix[7][18] = 8'b00111101;
        image_matrix[7][19] = 8'b00100001;
        image_matrix[7][20] = 8'b00000000;
        image_matrix[7][21] = 8'b00000000;
        image_matrix[7][22] = 8'b00000000;
        image_matrix[7][23] = 8'b00000000;
        image_matrix[8][0] = 8'b00000000;
        image_matrix[8][1] = 8'b00000000;
        image_matrix[8][2] = 8'b00011101;
        image_matrix[8][3] = 8'b00000000;
        image_matrix[8][4] = 8'b00000000;
        image_matrix[8][5] = 8'b00000000;
        image_matrix[8][6] = 8'b00000000;
        image_matrix[8][7] = 8'b00000000;
        image_matrix[8][8] = 8'b00000000;
        image_matrix[8][9] = 8'b00000000;
        image_matrix[8][10] = 8'b00000000;
        image_matrix[8][11] = 8'b00000000;
        image_matrix[8][12] = 8'b00000000;
        image_matrix[8][13] = 8'b00000000;
        image_matrix[8][14] = 8'b00000000;
        image_matrix[8][15] = 8'b00000000;
        image_matrix[8][16] = 8'b00000000;
        image_matrix[8][17] = 8'b00100000;
        image_matrix[8][18] = 8'b00110010;
        image_matrix[8][19] = 8'b00000000;
        image_matrix[8][20] = 8'b00000000;
        image_matrix[8][21] = 8'b00000000;
        image_matrix[8][22] = 8'b00000000;
        image_matrix[8][23] = 8'b00000000;
        image_matrix[9][0] = 8'b00000000;
        image_matrix[9][1] = 8'b00000000;
        image_matrix[9][2] = 8'b00001001;
        image_matrix[9][3] = 8'b00001010;
        image_matrix[9][4] = 8'b00000000;
        image_matrix[9][5] = 8'b00010010;
        image_matrix[9][6] = 8'b00010110;
        image_matrix[9][7] = 8'b00010010;
        image_matrix[9][8] = 8'b00000011;
        image_matrix[9][9] = 8'b00000000;
        image_matrix[9][10] = 8'b00000000;
        image_matrix[9][11] = 8'b00000000;
        image_matrix[9][12] = 8'b00000000;
        image_matrix[9][13] = 8'b00000000;
        image_matrix[9][14] = 8'b00111000;
        image_matrix[9][15] = 8'b00110101;
        image_matrix[9][16] = 8'b01000101;
        image_matrix[9][17] = 8'b01001100;
        image_matrix[9][18] = 8'b00000000;
        image_matrix[9][19] = 8'b00000000;
        image_matrix[9][20] = 8'b00000000;
        image_matrix[9][21] = 8'b00000000;
        image_matrix[9][22] = 8'b00000000;
        image_matrix[9][23] = 8'b00000000;
        image_matrix[10][0] = 8'b00000000;
        image_matrix[10][1] = 8'b00000000;
        image_matrix[10][2] = 8'b00000000;
        image_matrix[10][3] = 8'b00000000;
        image_matrix[10][4] = 8'b00000000;
        image_matrix[10][5] = 8'b00000000;
        image_matrix[10][6] = 8'b00000000;
        image_matrix[10][7] = 8'b00000000;
        image_matrix[10][8] = 8'b00000000;
        image_matrix[10][9] = 8'b00000000;
        image_matrix[10][10] = 8'b00001001;
        image_matrix[10][11] = 8'b00000000;
        image_matrix[10][12] = 8'b00001111;
        image_matrix[10][13] = 8'b00111111;
        image_matrix[10][14] = 8'b00111101;
        image_matrix[10][15] = 8'b01001000;
        image_matrix[10][16] = 8'b01010011;
        image_matrix[10][17] = 8'b01000101;
        image_matrix[10][18] = 8'b00000000;
        image_matrix[10][19] = 8'b00000000;
        image_matrix[10][20] = 8'b00000000;
        image_matrix[10][21] = 8'b00000000;
        image_matrix[10][22] = 8'b00000000;
        image_matrix[10][23] = 8'b00000000;
        image_matrix[11][0] = 8'b00000000;
        image_matrix[11][1] = 8'b00000000;
        image_matrix[11][2] = 8'b00000000;
        image_matrix[11][3] = 8'b00000000;
        image_matrix[11][4] = 8'b00000000;
        image_matrix[11][5] = 8'b00000000;
        image_matrix[11][6] = 8'b00000000;
        image_matrix[11][7] = 8'b00000000;
        image_matrix[11][8] = 8'b00000000;
        image_matrix[11][9] = 8'b00000000;
        image_matrix[11][10] = 8'b00000000;
        image_matrix[11][11] = 8'b00000000;
        image_matrix[11][12] = 8'b00101010;
        image_matrix[11][13] = 8'b01000010;
        image_matrix[11][14] = 8'b01000011;
        image_matrix[11][15] = 8'b01001101;
        image_matrix[11][16] = 8'b01001111;
        image_matrix[11][17] = 8'b00000000;
        image_matrix[11][18] = 8'b00000000;
        image_matrix[11][19] = 8'b00000000;
        image_matrix[11][20] = 8'b00000000;
        image_matrix[11][21] = 8'b00000000;
        image_matrix[11][22] = 8'b00000000;
        image_matrix[11][23] = 8'b00000000;
        image_matrix[12][0] = 8'b00000000;
        image_matrix[12][1] = 8'b00000000;
        image_matrix[12][2] = 8'b00000000;
        image_matrix[12][3] = 8'b00000000;
        image_matrix[12][4] = 8'b00000000;
        image_matrix[12][5] = 8'b00000000;
        image_matrix[12][6] = 8'b00000000;
        image_matrix[12][7] = 8'b00000000;
        image_matrix[12][8] = 8'b00000000;
        image_matrix[12][9] = 8'b00000000;
        image_matrix[12][10] = 8'b00000000;
        image_matrix[12][11] = 8'b00000000;
        image_matrix[12][12] = 8'b00110110;
        image_matrix[12][13] = 8'b00111110;
        image_matrix[12][14] = 8'b01000110;
        image_matrix[12][15] = 8'b01001111;
        image_matrix[12][16] = 8'b00110100;
        image_matrix[12][17] = 8'b00000000;
        image_matrix[12][18] = 8'b00000000;
        image_matrix[12][19] = 8'b00000000;
        image_matrix[12][20] = 8'b00000000;
        image_matrix[12][21] = 8'b00000000;
        image_matrix[12][22] = 8'b00000000;
        image_matrix[12][23] = 8'b00000000;
        image_matrix[13][0] = 8'b00000000;
        image_matrix[13][1] = 8'b00000000;
        image_matrix[13][2] = 8'b00000000;
        image_matrix[13][3] = 8'b00000000;
        image_matrix[13][4] = 8'b00000000;
        image_matrix[13][5] = 8'b00000000;
        image_matrix[13][6] = 8'b00000000;
        image_matrix[13][7] = 8'b00000000;
        image_matrix[13][8] = 8'b00000000;
        image_matrix[13][9] = 8'b00000000;
        image_matrix[13][10] = 8'b00000000;
        image_matrix[13][11] = 8'b00011111;
        image_matrix[13][12] = 8'b00111010;
        image_matrix[13][13] = 8'b00111100;
        image_matrix[13][14] = 8'b01000101;
        image_matrix[13][15] = 8'b01001010;
        image_matrix[13][16] = 8'b00000000;
        image_matrix[13][17] = 8'b00000000;
        image_matrix[13][18] = 8'b00000000;
        image_matrix[13][19] = 8'b00000000;
        image_matrix[13][20] = 8'b00000000;
        image_matrix[13][21] = 8'b00000000;
        image_matrix[13][22] = 8'b00000000;
        image_matrix[13][23] = 8'b00000000;
        image_matrix[14][0] = 8'b00000000;
        image_matrix[14][1] = 8'b00000000;
        image_matrix[14][2] = 8'b00000000;
        image_matrix[14][3] = 8'b00000000;
        image_matrix[14][4] = 8'b00000000;
        image_matrix[14][5] = 8'b00000000;
        image_matrix[14][6] = 8'b00000000;
        image_matrix[14][7] = 8'b00000000;
        image_matrix[14][8] = 8'b00000000;
        image_matrix[14][9] = 8'b00000000;
        image_matrix[14][10] = 8'b00010010;
        image_matrix[14][11] = 8'b00111101;
        image_matrix[14][12] = 8'b00111111;
        image_matrix[14][13] = 8'b01000100;
        image_matrix[14][14] = 8'b01010000;
        image_matrix[14][15] = 8'b00111010;
        image_matrix[14][16] = 8'b00000000;
        image_matrix[14][17] = 8'b00000000;
        image_matrix[14][18] = 8'b00000000;
        image_matrix[14][19] = 8'b00000000;
        image_matrix[14][20] = 8'b00000000;
        image_matrix[14][21] = 8'b00000000;
        image_matrix[14][22] = 8'b00000000;
        image_matrix[14][23] = 8'b00000000;
        image_matrix[15][0] = 8'b00000000;
        image_matrix[15][1] = 8'b00000000;
        image_matrix[15][2] = 8'b00000000;
        image_matrix[15][3] = 8'b00000000;
        image_matrix[15][4] = 8'b00000000;
        image_matrix[15][5] = 8'b00000000;
        image_matrix[15][6] = 8'b00000000;
        image_matrix[15][7] = 8'b00000000;
        image_matrix[15][8] = 8'b00000000;
        image_matrix[15][9] = 8'b00000000;
        image_matrix[15][10] = 8'b00110110;
        image_matrix[15][11] = 8'b01000011;
        image_matrix[15][12] = 8'b01000100;
        image_matrix[15][13] = 8'b01010001;
        image_matrix[15][14] = 8'b01010000;
        image_matrix[15][15] = 8'b00000000;
        image_matrix[15][16] = 8'b00000000;
        image_matrix[15][17] = 8'b00000000;
        image_matrix[15][18] = 8'b00000000;
        image_matrix[15][19] = 8'b00000000;
        image_matrix[15][20] = 8'b00000000;
        image_matrix[15][21] = 8'b00000000;
        image_matrix[15][22] = 8'b00000000;
        image_matrix[15][23] = 8'b00000000;
        image_matrix[16][0] = 8'b00000000;
        image_matrix[16][1] = 8'b00000000;
        image_matrix[16][2] = 8'b00000000;
        image_matrix[16][3] = 8'b00000000;
        image_matrix[16][4] = 8'b00000000;
        image_matrix[16][5] = 8'b00000000;
        image_matrix[16][6] = 8'b00000000;
        image_matrix[16][7] = 8'b00000000;
        image_matrix[16][8] = 8'b00000000;
        image_matrix[16][9] = 8'b00101110;
        image_matrix[16][10] = 8'b01000010;
        image_matrix[16][11] = 8'b01000000;
        image_matrix[16][12] = 8'b01010000;
        image_matrix[16][13] = 8'b01010011;
        image_matrix[16][14] = 8'b00110001;
        image_matrix[16][15] = 8'b00000000;
        image_matrix[16][16] = 8'b00000000;
        image_matrix[16][17] = 8'b00000000;
        image_matrix[16][18] = 8'b00000000;
        image_matrix[16][19] = 8'b00000000;
        image_matrix[16][20] = 8'b00000000;
        image_matrix[16][21] = 8'b00000000;
        image_matrix[16][22] = 8'b00000000;
        image_matrix[16][23] = 8'b00000000;
        image_matrix[17][0] = 8'b00000000;
        image_matrix[17][1] = 8'b00000000;
        image_matrix[17][2] = 8'b00000000;
        image_matrix[17][3] = 8'b00000000;
        image_matrix[17][4] = 8'b00000000;
        image_matrix[17][5] = 8'b00000000;
        image_matrix[17][6] = 8'b00000000;
        image_matrix[17][7] = 8'b00000000;
        image_matrix[17][8] = 8'b00000000;
        image_matrix[17][9] = 8'b01000010;
        image_matrix[17][10] = 8'b01000011;
        image_matrix[17][11] = 8'b01001001;
        image_matrix[17][12] = 8'b01010100;
        image_matrix[17][13] = 8'b01000111;
        image_matrix[17][14] = 8'b00000000;
        image_matrix[17][15] = 8'b00000000;
        image_matrix[17][16] = 8'b00000000;
        image_matrix[17][17] = 8'b00000000;
        image_matrix[17][18] = 8'b00000000;
        image_matrix[17][19] = 8'b00000000;
        image_matrix[17][20] = 8'b00000000;
        image_matrix[17][21] = 8'b00000000;
        image_matrix[17][22] = 8'b00000000;
        image_matrix[17][23] = 8'b00000000;
        image_matrix[18][0] = 8'b00000000;
        image_matrix[18][1] = 8'b00000000;
        image_matrix[18][2] = 8'b00000000;
        image_matrix[18][3] = 8'b00000000;
        image_matrix[18][4] = 8'b00000000;
        image_matrix[18][5] = 8'b00000000;
        image_matrix[18][6] = 8'b00000000;
        image_matrix[18][7] = 8'b00000000;
        image_matrix[18][8] = 8'b00110010;
        image_matrix[18][9] = 8'b00111110;
        image_matrix[18][10] = 8'b00111111;
        image_matrix[18][11] = 8'b01010010;
        image_matrix[18][12] = 8'b01001101;
        image_matrix[18][13] = 8'b00000000;
        image_matrix[18][14] = 8'b00000000;
        image_matrix[18][15] = 8'b00000000;
        image_matrix[18][16] = 8'b00000000;
        image_matrix[18][17] = 8'b00000000;
        image_matrix[18][18] = 8'b00000000;
        image_matrix[18][19] = 8'b00000000;
        image_matrix[18][20] = 8'b00000000;
        image_matrix[18][21] = 8'b00000000;
        image_matrix[18][22] = 8'b00000000;
        image_matrix[18][23] = 8'b00000000;
        image_matrix[19][0] = 8'b00000000;
        image_matrix[19][1] = 8'b00000000;
        image_matrix[19][2] = 8'b00000000;
        image_matrix[19][3] = 8'b00000000;
        image_matrix[19][4] = 8'b00000000;
        image_matrix[19][5] = 8'b00000000;
        image_matrix[19][6] = 8'b00000000;
        image_matrix[19][7] = 8'b00100100;
        image_matrix[19][8] = 8'b01000011;
        image_matrix[19][9] = 8'b01000000;
        image_matrix[19][10] = 8'b01001100;
        image_matrix[19][11] = 8'b01010000;
        image_matrix[19][12] = 8'b00100111;
        image_matrix[19][13] = 8'b00000000;
        image_matrix[19][14] = 8'b00000000;
        image_matrix[19][15] = 8'b00000000;
        image_matrix[19][16] = 8'b00000000;
        image_matrix[19][17] = 8'b00000000;
        image_matrix[19][18] = 8'b00000000;
        image_matrix[19][19] = 8'b00000000;
        image_matrix[19][20] = 8'b00000000;
        image_matrix[19][21] = 8'b00000000;
        image_matrix[19][22] = 8'b00000000;
        image_matrix[19][23] = 8'b00000000;
        image_matrix[20][0] = 8'b00000000;
        image_matrix[20][1] = 8'b00000000;
        image_matrix[20][2] = 8'b00000000;
        image_matrix[20][3] = 8'b00000000;
        image_matrix[20][4] = 8'b00000000;
        image_matrix[20][5] = 8'b00000000;
        image_matrix[20][6] = 8'b00001101;
        image_matrix[20][7] = 8'b00111011;
        image_matrix[20][8] = 8'b01000001;
        image_matrix[20][9] = 8'b01010001;
        image_matrix[20][10] = 8'b01010101;
        image_matrix[20][11] = 8'b01001001;
        image_matrix[20][12] = 8'b00000000;
        image_matrix[20][13] = 8'b00000000;
        image_matrix[20][14] = 8'b00000000;
        image_matrix[20][15] = 8'b00000000;
        image_matrix[20][16] = 8'b00000000;
        image_matrix[20][17] = 8'b00000000;
        image_matrix[20][18] = 8'b00000000;
        image_matrix[20][19] = 8'b00000000;
        image_matrix[20][20] = 8'b00000000;
        image_matrix[20][21] = 8'b00000000;
        image_matrix[20][22] = 8'b00000000;
        image_matrix[20][23] = 8'b00000000;
        image_matrix[21][0] = 8'b00000000;
        image_matrix[21][1] = 8'b00000000;
        image_matrix[21][2] = 8'b00000000;
        image_matrix[21][3] = 8'b00000000;
        image_matrix[21][4] = 8'b00000000;
        image_matrix[21][5] = 8'b00000000;
        image_matrix[21][6] = 8'b00101000;
        image_matrix[21][7] = 8'b01000001;
        image_matrix[21][8] = 8'b01000100;
        image_matrix[21][9] = 8'b01011000;
        image_matrix[21][10] = 8'b01010100;
        image_matrix[21][11] = 8'b00110011;
        image_matrix[21][12] = 8'b00000000;
        image_matrix[21][13] = 8'b00000000;
        image_matrix[21][14] = 8'b00000000;
        image_matrix[21][15] = 8'b00000000;
        image_matrix[21][16] = 8'b00000000;
        image_matrix[21][17] = 8'b00000000;
        image_matrix[21][18] = 8'b00000000;
        image_matrix[21][19] = 8'b00000000;
        image_matrix[21][20] = 8'b00000000;
        image_matrix[21][21] = 8'b00000000;
        image_matrix[21][22] = 8'b00000000;
        image_matrix[21][23] = 8'b00000000;
        image_matrix[22][0] = 8'b00000000;
        image_matrix[22][1] = 8'b00000000;
        image_matrix[22][2] = 8'b00000000;
        image_matrix[22][3] = 8'b00000000;
        image_matrix[22][4] = 8'b00000000;
        image_matrix[22][5] = 8'b00000000;
        image_matrix[22][6] = 8'b00101100;
        image_matrix[22][7] = 8'b00111110;
        image_matrix[22][8] = 8'b01001111;
        image_matrix[22][9] = 8'b01010001;
        image_matrix[22][10] = 8'b01001001;
        image_matrix[22][11] = 8'b00100011;
        image_matrix[22][12] = 8'b00000000;
        image_matrix[22][13] = 8'b00000000;
        image_matrix[22][14] = 8'b00000000;
        image_matrix[22][15] = 8'b00000000;
        image_matrix[22][16] = 8'b00000000;
        image_matrix[22][17] = 8'b00000000;
        image_matrix[22][18] = 8'b00000000;
        image_matrix[22][19] = 8'b00000000;
        image_matrix[22][20] = 8'b00000000;
        image_matrix[22][21] = 8'b00000000;
        image_matrix[22][22] = 8'b00000000;
        image_matrix[22][23] = 8'b00000000;
        image_matrix[23][0] = 8'b00000000;
        image_matrix[23][1] = 8'b00000000;
        image_matrix[23][2] = 8'b00000000;
        image_matrix[23][3] = 8'b00000000;
        image_matrix[23][4] = 8'b00000000;
        image_matrix[23][5] = 8'b00000000;
        image_matrix[23][6] = 8'b00000000;
        image_matrix[23][7] = 8'b00100001;
        image_matrix[23][8] = 8'b01000011;
        image_matrix[23][9] = 8'b00111001;
        image_matrix[23][10] = 8'b00000000;
        image_matrix[23][11] = 8'b00000000;
        image_matrix[23][12] = 8'b00000000;
        image_matrix[23][13] = 8'b00000000;
        image_matrix[23][14] = 8'b00000000;
        image_matrix[23][15] = 8'b00000000;
        image_matrix[23][16] = 8'b00000000;
        image_matrix[23][17] = 8'b00000000;
        image_matrix[23][18] = 8'b00000000;
        image_matrix[23][19] = 8'b00000000;
        image_matrix[23][20] = 8'b00000000;
        image_matrix[23][21] = 8'b00000000;
        image_matrix[23][22] = 8'b00000000;
        image_matrix[23][23] = 8'b00000000;



        flatten_input();  // Convert to flat input
        start <= 1'b1;
        wait(done);
        start <= 1'b0;
        print_output();
        
        fd = $fopen(filename, "w");
        if (fd == 0) begin
          $display("ERROR: Could not open file %s", filename);
          $finish;
        end
    
        for (int i = 0; i < ROW/2; i++) begin
          for (int j = 0; j < COL/2; j++) begin
            // Write each N-bit value as binary string
            $fwrite(fd, "%b\n",unpacked[i][j]);
          end
        end
    
        $fclose(fd);
        $display("Data written to %s", filename);
        
        
        @(posedge clk);
        @(posedge clk);
        for (i = 0; i < ROW; i = i + 1) begin
            for (j = 0; j < COL; j = j + 1) begin
                image_matrix[i][j] = 8'b01010000;  // values 0 to 63
            end
        end
        flatten_input();  // Convert to flat input
        start <= 1'b1;
        wait(done);
        start <= 1'b0;
        print_output();
        $finish;
    end

endmodule
