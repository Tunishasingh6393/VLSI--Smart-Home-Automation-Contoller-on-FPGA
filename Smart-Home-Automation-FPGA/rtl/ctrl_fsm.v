// =========================================================================
// Module: ctrl_fsm
// Description: Core priority controller logic utilizing standard FSM design.
//              Handles Mode priorities: ALARM > MANUAL > AUTO > SCHEDULE.
// =========================================================================
module ctrl_fsm(
    input  wire        clk,             // Master clock
    input  wire        rst_n,           // Asynchronous active-low reset
    input  wire        tick_10,         // 10 Hz scheduler state base tick
    
    // Core External Sensor Inputs
    input  wire        pir,             // Motion sensor alert high
    input  wire        dark,            // Low Light level LDR indicator high
    input  wire        overcur,         // Direct circuit safety trip input (Critical)
    input  wire        door_open,       // Door magnetic status contact
    input  wire        security_armed,  // System armed configuration switch
    
    // Commands & Interrupt Handlers
    input  wire        manual_evt,      // Switch toggle detected, triggers manual mode
    input  wire [2:0]  manual_scene_idx,// Selected manual layout lookup index
    
    // Remote Overrides (via ESP32 UART bridge)
    input  wire        uart_cmd_stb,    // Valid packet deciphered
    input  wire [2:0]  uart_cmd_type,   // 3-bit command category register
    input  wire [7:0]  uart_cmd_val,    // Accompanying 8-bit parameter payload
    
    // Automations (Schedules & Sensors)
    input  wire        sched_valid,     // Active time tick matching active rules
    input  wire [2:0]  sched_scene_idx, // Preset scene loaded automatically by time
    
    // Output Registers
    output reg   [7:0] dutyL0, dutyL1, dutyL2, dutyL3, // Light dimers values
    output reg   [7:0] dutyF0, dutyF1,                 // Fan speed controllers values
    output reg   [3:0] relays,                         // Directly targeted socket states
    output reg         alarm_active,                   // Red light / Buzzer driver status
    output reg   [1:0] current_mode,                   // Reports state indicator to top-level
    output reg   [15:0] energy_saving_timer            // Auto-off timer when idle
);

    // Human-readable State Declarations using standard Parameters
    parameter S_MANUAL   = 2'b00;
    parameter S_SCHEDULE = 2'b01;
    parameter S_AUTO     = 2'b10;
    parameter S_ALARM    = 2'b11;

    reg [1:0] state, next_state;
    
    // Internal shadow registers
    wire [7:0] s_L0, s_L1, s_L2, s_L3, s_F0, s_F1;
    wire [3:0] s_R;
    
    // Shared LUT decoder instance for Scene Index parsing
    reg [2:0] scene_decoder_idx;
    scenes scene_inst (
        .clk(clk),
        .idx(scene_decoder_idx),
        .L0(s_L0), .L1(s_L1), .L2(s_L2), .L3(s_L3),
        .F0(s_F0), .F1(s_F1),
        .R(s_R)
    );

    // Energy saving logic variables
    reg [15:0] auto_off_cnt;

    // FSM State Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_MANUAL;
        end else begin
            state <= next_state;
        end
    end

    // FSM Next-State Logic Decoders representing human automation parameters
    always @(*) begin
        // Always report current mode state to observers
        current_mode = state;
        
        // Asynchronous / synchronous priority logic evaluation
        if (overcur || (security_armed && door_open)) begin
            next_state = S_ALARM;
        end else begin
            case (state)
                S_ALARM: begin
                    // Remain in safe Alarm state unless overcurrent cleared and manual override applied
                    if (!overcur && !(security_armed && door_open) && manual_evt)
                        next_state = S_MANUAL;
                    else
                        next_state = S_ALARM;
                end
                
                S_MANUAL: begin
                    // Switch to sensor-mode automatically if PIR motion occurs in dark environment
                    if (pir && dark && !manual_evt)
                        next_state = S_AUTO;
                    // Or follow schedules if a timing boundary is struck
                    else if (sched_valid && !manual_evt)
                        next_state = S_SCHEDULE;
                    else
                        next_state = S_MANUAL;
                end
                
                S_AUTO: begin
                    // Interrupt SENSOR mode immediately if user commands manual change
                    if (manual_evt || uart_cmd_stb)
                        next_state = S_MANUAL;
                    // Fallback to scheduling when motion times out
                    else if (auto_off_cnt == 0 && !pir)
                        next_state = S_SCHEDULE;
                    else
                        next_state = S_AUTO;
                end

                S_SCHEDULE: begin
                    // High-priority user interactions route to manual immediately
                    if (manual_evt || uart_cmd_stb)
                        next_state = S_MANUAL;
                    else if (pir && dark)
                        next_state = S_AUTO;
                    else
                        next_state = S_SCHEDULE;
                end

                default: next_state = S_MANUAL;
            endcase
        end
    end

    // Energy Saving Count Timer logic driven by the 10 Hz timing tick reference
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            auto_off_cnt <= 16'd600; // 60 seconds at 10 Hz
            energy_saving_timer <= 16'd600;
        end else if (tick_10) begin
            if (pir) begin
                auto_off_cnt <= 16'd600; // Reset countdown as motion is actively maintained
            end else if (auto_off_cnt > 0) begin
                auto_off_cnt <= auto_off_cnt - 1;
            end
            energy_saving_timer <= auto_off_cnt;
        end
    end

    // Output assignment blocks governed by state decoders
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dutyL0 <= 8'd0; dutyL1 <= 8'd0; dutyL2 <= 8'd0; dutyL3 <= 8'd0;
            dutyF0 <= 8'd0; dutyF1 <= 8'd0;
            relays <= 4'b0000;
            alarm_active <= 1'b0;
            scene_decoder_idx <= 3'd0;
        end else begin
            // Core safety alarms handling
            if (state == S_ALARM) begin
                alarm_active <= 1'b1;
                relays       <= 4'b0000; // Safely trip all high voltage isolation paths
                // Overcurrent: keep lights off; Burglar intruder: strobe lights full bright to scare burglar
                if (overcur) begin
                    dutyL0 <= 8'd0; dutyL1 <= 8'd0; dutyL2 <= 8'd0; dutyL3 <= 8'd0;
                end else begin
                    dutyL0 <= 8'd255; dutyL1 <= 8'd255; dutyL2 <= 8'd255; dutyL3 <= 8'd255;
                end
                dutyF0 <= 8'd0; dutyF1 <= 8'd0;
            end else begin
                alarm_active <= 1'b0;
                
                case (state)
                    S_MANUAL: begin
                        // Map directly to decoded standard scenes selected by structural switches
                        scene_decoder_idx <= manual_scene_idx;
                        dutyL0 <= s_L0; dutyL1 <= s_L1; dutyL2 <= s_L2; dutyL3 <= s_L3;
                        dutyF0 <= s_F0; dutyF1 <= s_F1;
                        relays <= s_R;

                        // ESP32 Direct Register Writes via UART interface override the active scene
                        if (uart_cmd_stb) begin
                            case (uart_cmd_type)
                                3'd1: dutyL0 <= uart_cmd_val; // Direct register control
                                3'd2: dutyL1 <= uart_cmd_val;
                                3'd3: dutyL2 <= uart_cmd_val;
                                3'd4: dutyL3 <= uart_cmd_val;
                                3'd5: dutyF0 <= uart_cmd_val; // Fan 0 Write
                                3'd6: dutyF1 <= uart_cmd_val; // Fan 1 Write
                                3'd7: relays <= uart_cmd_val[3:0]; // Direct mask override
                            endcase
                        end
                    end
                    
                    S_AUTO: begin
                        // Under sensor guidance, turn ON entrance lights safely
                        // Apply soft Eco presets (bright entries L0, dimmer paths L1-L3)
                        dutyL0 <= 8'd180; // Entry light active
                        dutyL1 <= 8'd100;
                        dutyL2 <= 8'd20; 
                        dutyL3 <= 8'd0;
                        dutyF0 <= 8'd120; // Fan kept comfortable
                        dutyF1 <= 8'd0;
                        relays <= 4'b0011; // Basic sockets live
                    end
                    
                    S_SCHEDULE: begin
                        // Scheduler sets preset scene coordinates
                        scene_decoder_idx <= sched_scene_idx;
                        dutyL0 <= s_L0; dutyL1 <= s_L1; dutyL2 <= s_L2; dutyL3 <= s_L3;
                        dutyF0 <= s_F0; dutyF1 <= s_F1;
                        relays <= s_R;
                    end
                endcase
            end
        end
    end
endmodule
