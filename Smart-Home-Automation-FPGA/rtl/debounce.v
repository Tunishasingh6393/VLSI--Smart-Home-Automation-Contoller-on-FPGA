// =========================================================================
// Module: debounce
// Description: Synchronizes raw inputs to system clock and filters mechanical 
//              switch bounce. Outputs debounced levels and single-cycle trigger pulses.
// =========================================================================
module debounce #(
    parameter integer CNT = 5  // Number of tick cycles requested for stability
)(
    input  wire clk,        // System master clock
    input  wire rst_n,      // Asynchronous global reset
    input  wire tick,       // Debounce timing base tick input (typically 10 Hz)
    input  wire async_in,   // Noisy asynchronous physical signal
    output reg  level,      // Settled stable level value
    output reg  rise_pulse  // Single cycle strobe raised on rising edge
);

    // 2-stage Flip-Flop synchronizer to prevent metastability
    reg s1, s2;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s1 <= 1'b0;
            s2 <= 1'b0;
        end else begin
            s1 <= async_in;
            s2 <= s1;
        end
    end

    reg [$clog2(CNT+1)-1:0] db_cnt;
    reg stable;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            db_cnt     <= 0;
            stable     <= 1'b0;
            level      <= 1'b0;
            rise_pulse <= 1'b0;
        end else begin
            rise_pulse <= 1'b0;
            
            if (tick) begin
                if (s2 != stable) begin
                    db_cnt <= db_cnt + 1;
                    if (db_cnt == CNT) begin
                        stable <= s2;
                        db_cnt <= 0;
                    end
                end else begin
                    db_cnt <= 0;
                end

                if (stable && !level) begin
                    level      <= 1'b1;
                    rise_pulse <= 1'b1; // Raise rising edge pulse on transition
                end else if (!stable) begin
                    level      <= 1'b0;
                end
            end
        end
    end
endmodule
