// =============================================================================
// strassen_controller.v — Verilog
// Parallel FSM orchestrating the concurrent 7-product Strassen execution
// =============================================================================
`include "fixed_pkg.vh"
`include "strassen_pkg.vh"

module strassen_controller #(
    parameter SZI         = `DEFAULT_SZI,
    parameter SZJ         = `DEFAULT_SZJ,
    parameter DATA_WIDTH  = `DATA_WIDTH
) (
    input  wire                             clk,
    input  wire                             resetn,

    // Top level trigger
    input  wire                             start,
    output reg                              done,

    // Parallel preprocessor control
    output reg                              pre_start,
    input  wire                             pre_done,

    // Parallel postprocessor stage 1 control
    output reg                              post_start1,
    input  wire                             post_done1,

    // Parallel postprocessor stage 2 control
    output reg                              post_start2,
    input  wire                             post_done2,

    // Systolic Array controls (shared across all 7 arrays)
    output reg                              sys_load_weight,
    output reg                              sys_clear_quire,
    output reg                              sys_shift_out,
    output reg                              sys_shift_load,

    // Step counter and state
    output reg [3:0]                        state,
    output reg [7:0]                        cnt
);

    // FSM states
    localparam [3:0]
        IDLE           = 4'd0,
        RUN_SYSTOLIC   = 4'd1,
        CAPTURE        = 4'd2,
        SHIFT_OUT      = 4'd3,
        WAIT_WRITEBACK = 4'd4,
        DONE_STATE     = 4'd5;

    reg [3:0] next_state;

    // FSM State transitions
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            state <= IDLE;
            cnt   <= 8'd0;
        end else begin
            state <= next_state;
            if (state != next_state)
                cnt <= 8'd0;
            else
                cnt <= cnt + 8'd1;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = RUN_SYSTOLIC;
            end
            RUN_SYSTOLIC: begin
                if (cnt == SZI + 2*SZJ + 1) next_state = CAPTURE;
            end
            CAPTURE: begin
                next_state = SHIFT_OUT;
            end
            SHIFT_OUT: begin
                if (cnt == SZI - 1) next_state = WAIT_WRITEBACK;
            end
            WAIT_WRITEBACK: begin
                if (cnt == 8'd11) next_state = DONE_STATE;
            end
            DONE_STATE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Control path output logic
    always @(*) begin
        done             = 1'b0;
        pre_start        = 1'b0;
        post_start1      = 1'b0;
        post_start2      = 1'b0;

        sys_load_weight  = 1'b0;
        sys_clear_quire  = 1'b0;
        sys_shift_out    = 1'b0;
        sys_shift_load   = 1'b0;

        case (state)
            IDLE: begin
                sys_clear_quire = 1'b1;
            end

            RUN_SYSTOLIC: begin
                if (cnt == 8'd0) sys_clear_quire = 1'b1;
                sys_load_weight = 1'b1;
            end

            CAPTURE: begin
                sys_shift_load = 1'b1;
            end

            SHIFT_OUT: begin
                sys_shift_out = 1'b1;
            end

            DONE_STATE: begin
                done = 1'b1;
            end
            default: ;
        endcase
    end

endmodule
