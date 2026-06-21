// =========================================================================
// Module: clk_en
// Description: Dual clock-enable tick generator. Creates single-cycle master
//              strobes from a primary clock to coordinate real-time subsystems.
// =========================================================================
module clk_en #(
    parameter integer CLK_HZ  = 50_000_000, // System input clock (50 MHz)
    parameter integer TICK_HZ = 1000        // Target tick output strobe (1 kHz)
)(
    input  wire clk,      // System clock input
    input  wire rst_n,    // Active-low asynchronous reset
    output reg  tick      // Pulsed output high for exactly 1 clock cycle at TICK_HZ
);

    localparam integer DIV = CLK_HZ / TICK_HZ;
    reg [$clog2(DIV)-1:0] cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt  <= 0;
            tick <= 1'b0;
        end else begin
            tick <= 1'b0;
            if (cnt == DIV - 1) begin
                cnt  <= 0;
                tick <= 1'b1;
            end else begin
                cnt  <= cnt + 1'b1;
            end
        end
    end
endmodule
