// =========================================================================
// Module: pwm8
// Description: Generates standard 8-bit resolution PWM signal. 
//              Higher duty cycles yield long pulses, corresponding to high loads.
// =========================================================================
module pwm8(
    input  wire clk,       // System clock
    input  wire rst_n,     // Asynchronous reset
    input  wire tick_1k,   // 1 kHz execution strobe incrementing the pulse counter
    input  wire [7:0] duty, // Control registers value (0 to 255)
    output reg  out        // Modulated output driving external MOSFET/Gate driver
);

    reg [7:0] cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt <= 8'd0;
            out <= 1'b0;
        end else if (tick_1k) begin
            cnt <= cnt + 8'd1;
            out <= (cnt < duty);
        end
    end
endmodule
