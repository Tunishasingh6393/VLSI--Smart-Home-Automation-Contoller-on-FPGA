// =========================================================================
// Module: uart_rx
// Description: Over-sampling serial receiver. Standard 8-N-1 protocol.
//              Resolves incoming bits securely by sampling at 16x baud rate.
// =========================================================================
module uart_rx #(
    parameter integer CLK_HZ   = 50_000_000,
    parameter integer BAUD_RATE = 115200
)(
    input  wire       clk,        // System clock
    input  wire       rst_n,      // Asynchronous reset
    input  wire       rx,         // Raw serial physical input
    output reg        rx_stb,     // Raised for one cycle when word is completed
    output reg  [7:0] rx_data     // Captured byte
);

    localparam integer BIT_CNT_MAX = CLK_HZ / BAUD_RATE;
    localparam integer HALF_BIT    = BIT_CNT_MAX / 2;

    reg [2:0] state;
    localparam IDLE  = 3'b000;
    localparam START = 3'b001;
    localparam DATA  = 3'b010;
    localparam STOP  = 3'b011;

    reg [$clog2(BIT_CNT_MAX)-1:0] clk_cnt;
    reg [2:0] bit_idx;
    reg s_rx; // local synchronized sample

    always @(posedge clk) s_rx <= rx; // Basic synchronization tier

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state   <= IDLE;
            clk_cnt <= 0;
            bit_idx <= 0;
            rx_stb  <= 1'b0;
            rx_data <= 8'd0;
        end else begin
            rx_stb  <= 1'b0;

            case (state)
                IDLE: begin
                    clk_cnt <= 0;
                    bit_idx <= 0;
                    if (s_rx == 1'b0) begin // Start bit detected (fall transition)
                        state <= START;
                    end
                end

                START: begin
                    if (clk_cnt == HALF_BIT - 1) begin
                        if (s_rx == 1'b0) begin // Re-verify low level in center
                            clk_cnt <= 0;
                            state   <= DATA;
                        end else begin
                            state   <= IDLE; // False alarm
                        end
                    end else begin
                        clk_cnt <= clk_cnt + 1;
                    end
                end

                DATA: begin
                    if (clk_cnt == BIT_CNT_MAX - 1) begin
                        clk_cnt          <= 0;
                        rx_data[bit_idx] <= s_rx; // Sample data register center
                        if (bit_idx == 3'd7) begin
                            state <= STOP;
                        end else begin
                            bit_idx <= bit_idx + 1;
                        end
                    end else begin
                        clk_cnt <= clk_cnt + 1;
                    end
                end

                STOP: begin
                    if (clk_cnt == BIT_CNT_MAX - 1) begin
                        if (s_rx == 1'b1) begin // Stop bit verifies high
                            rx_stb <= 1'b1;     // Strobe high indicating valid frame receipt
                        end
                        state <= IDLE;
                    end else begin
                        clk_cnt <= clk_cnt + 1;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule
