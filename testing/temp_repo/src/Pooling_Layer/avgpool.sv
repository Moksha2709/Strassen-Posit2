module avgpool#(
    parameter N   = 8,
    parameter ROW = 8,
    parameter COL = 8,
    parameter ES  = 1
)(
    input  logic clk,
    input  logic rst,
    input  logic start,  // << NEW START SIGNAL
    input  logic [ROW*COL*N-1:0] image_i,
    output logic [(N*(ROW/2)*(COL/2))-1:0] result_o,
    output logic done
);

    int i, j;
    int idx1, idx2, idx3, idx4;
    logic [N-1:0] sum1, sum2;

    logic busy;
    logic [N-1:0] sum_out,mul_out;

    // Combinational POSIT additions for 2x2 patch
    posit_add #(.N(N), .es(ES)) add1 (
        .in1(image_i[idx1*N +: N]),
        .in2(image_i[idx2*N +: N]),
        .out(sum1)
    );

    posit_add #(.N(N), .es(ES)) add2 (
        .in1(image_i[idx3*N +: N]),
        .in2(image_i[idx4*N +: N]),
        .out(sum2)
    );

    // Final addition and write to output
    posit_add #(.N(N), .es(ES)) add3 (
        .in1(sum1),
        .in2(sum2),
        .out(sum_out)
    );
    
    posit_mult #(.N(N), .es(ES)) mul1 (.in1(sum_out), .in2(8'b00100000), .out(mul_out));

    // Main sequential logic
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            i     <= 0;
            j     <= 0;
            idx1  <= 0;
            idx2  <= 0;
            idx3  <= 0;
            idx4  <= 0;
            done  <= 0;
            busy  <= 0;
        end else begin
            if (start && !busy) begin
                // Start processing
                i    <= 0;
                j    <= 0;
                busy <= 1;
                done <= 0;
            end else if (busy) begin
                // Compute 2x2 patch indices
                idx1 <= (i * 2)     * COL + (j * 2);
                idx2 <= (i * 2)     * COL + (j * 2 + 1);
                idx3 <= (i * 2 + 1) * COL + (j * 2);
                idx4 <= (i * 2 + 1) * COL + (j * 2 + 1);

                // Advance through patches
                if (j == (COL / 2) - 1) begin
                    j <= 0;
                    if (i == (ROW / 2) - 1) begin
                        i    <= 0;
                        busy <= 0;
                        done <= 1'b1;
                    end else begin
                        i    <= i + 1;
                        done <= 0;
                    end
                end else begin
                    j    <= j + 1;
                    done <= 0;
                end
            end else begin
                // Idle state
                done <= 0;
            end
        end
    end
    
    always_ff @(posedge clk, posedge rst) begin
        if(rst) result_o[(i * (COL/2) + j)*N +: N] <= '0;
        else result_o[(i * (COL/2) + j)*N +: N] <= sum_out;
    end

endmodule
