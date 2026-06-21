// =========================================================================
// Module: scenes
// Description: Fast-access memory lookup of pre-programmed environments.
//              Provides unified values for standard rooms with a single trigger.
// =========================================================================
module scenes(
    input  wire        clk,        // System clock
    input  wire  [2:0] idx,        // Requested scene ID (0..7)
    output reg   [7:0] L0, L1, L2, L3, // Target dimmer registers
    output reg   [7:0] F0, F1,     // Target fan speeds
    output reg   [3:0] R           // Relay output masks
);

    always @(*) begin
        case(idx)
            3'd0: begin // ALL OFF (Emergency / Idle default)
                L0 = 8'd0;   L1 = 8'd0;   L2 = 8'd0;   L3 = 8'd0;
                F0 = 8'd0;   F1 = 8'd0;
                R  = 4'b0000;
            end
            3'd1: begin // Evening Mood (Chilled, low intensity ambient paths)
                L0 = 8'd60;  L1 = 8'd30;  L2 = 8'd20;  L3 = 8'd0;
                F0 = 8'd80;  F1 = 8'd0;
                R  = 4'b0001;
            end
            3'd2: begin // Activity / Work (Bright ambient light, cooling active)
                L0 = 8'd230; L1 = 8'd220; L2 = 8'd100; L3 = 8'd50;
                F0 = 8'd180; F1 = 8'd120;
                R  = 4'b1100;
            end
            3'd3: begin // Eco Saver (Low power paths, security active)
                L0 = 8'd20;  L1 = 8'd0;   L2 = 8'd20;  L3 = 8'd0;
                F0 = 8'd0;   F1 = 8'd0;
                R  = 4'b0010;
            end
            3'd4: begin // Night Safety Guide (Dimmed outlines, basic alarm armed)
                L0 = 8'd15;  L1 = 8'd5;   L2 = 8'd10;  L3 = 8'd5;
                F0 = 8'd50;  F1 = 8'd0;
                R  = 4'b0000;
            end
            3'd5: begin // Party / High Density Load (Full active sockets and maximum fans)
                L0 = 8'd255; L1 = 8'd255; L2 = 8'd150; L3 = 8'd150;
                F0 = 8'd255; F1 = 8'd255;
                R  = 4'b1111;
            end
            default: begin // Default safe states
                L0 = 8'd0;   L1 = 8'd0;   L2 = 8'd0;   L3 = 8'd0;
                F0 = 8'd0;   F1 = 8'd0;
                R  = 4'b0000;
            end
        endcase
    end
endmodule
