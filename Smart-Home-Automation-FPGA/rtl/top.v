// =========================================================================
// Module: top
// Description: Main structural top module binding inputs, clock managers,
//              sensor conditioning, priority FSM logic, and PWM output pins.
// =========================================================================
module top (
    input  wire        clk_50m,        // 50 MHz standard board clock
    input  wire        rst_btn,        // Master hardware active-high reset button
    
    // Sensor Interface Ports
    input  wire        pir_raw,        // Active-high physical PIR presence detector
    input  wire        ldr_dark_raw,   // Active-high light threshold indicator
    input  wire        overcur_raw,    // Circuit current loop sensor trip line
    input  wire        door_open_raw,  // Magnetic frame contact sensor
    input  wire        security_armed_raw, // Dashboard arm configuration switch
    
    // Manual Command Switch Pins
    input  wire        btn0_raw,       // Room 0 manually toggles
    input  wire        btn1_raw,       // Room 1 manually toggles
    input  wire        btn2_raw,       // Room 2 manually toggles
    input  wire        btn3_raw,       // Room 3 manually toggles
    input  wire [2:0]  manual_scene_sw, // Switch board Scene selector mapping
    
    // Serial Comms
    input  wire        uart_rx_pin,    // Input serial stream RX
    output wire        uart_tx_pin,    // Telemetry output transmitter TX
    
    // Actuator Output Interface Pins
    output wire        L0_PWM, L1_PWM, L2_PWM, L3_PWM, // Modulated LEDs dimmer
    output wire        F0_PWM, F1_PWM,                 // Fan controllers outputs
    output wire [3:0]  relays_out,                     // External solid-state high voltage relays
    output wire        alarm_buzzer,                   // Transistor switch-driven alert speaker
    output wire [1:0]  state_indicators                // Debugging LEDs reporting current state
);

    // Invert the physical high-active reset button to meet standard active-low design
    wire rst_n = ~rst_btn;

    // ---------------------------------------------------------
    // 1. Clock-Divider timing base generators
    // ---------------------------------------------------------
    wire tick_1k, tick_10;
    
    clk_en #(.CLK_HZ(50_000_000), .TICK_HZ(1000)) timer_1khz (
        .clk(clk_50m), .rst_n(rst_n), .tick(tick_1k)
    );
    
    clk_en #(.CLK_HZ(50_000_000), .TICK_HZ(10)) timer_10hz (
        .clk(clk_50m), .rst_n(rst_n), .tick(tick_10)
    );

    // ---------------------------------------------------------
    // 2. Conditioning and De-bouncers for Noisy Asynchronous Ports
    // ---------------------------------------------------------
    wire pir, dark, overcur, door_open, security_armed;
    wire b0, b1, b2, b3;

    debounce #(.CNT(5)) db_pir (.clk(clk_50m), .rst_n(rst_n), .tick(tick_10), .async_in(pir_raw), .level(pir), .rise_pulse());
    debounce #(.CNT(5)) db_dark(.clk(clk_50m), .rst_n(rst_n), .tick(tick_10), .async_in(ldr_dark_raw), .level(dark), .rise_pulse());
    debounce #(.CNT(5)) db_oc  (.clk(clk_50m), .rst_n(rst_n), .tick(tick_10), .async_in(overcur_raw), .level(overcur), .rise_pulse());
    debounce #(.CNT(5)) db_do  (.clk(clk_50m), .rst_n(rst_n), .tick(tick_10), .async_in(door_open_raw), .level(door_open), .rise_pulse());
    debounce #(.CNT(5)) db_sa  (.clk(clk_50m), .rst_n(rst_n), .tick(tick_10), .async_in(security_armed_raw), .level(security_armed), .rise_pulse());

    debounce #(.CNT(5)) db_b0  (.clk(clk_50m), .rst_n(rst_n), .tick(tick_10), .async_in(btn0_raw), .level(), .rise_pulse(b0));
    debounce #(.CNT(5)) db_b1  (.clk(clk_50m), .rst_n(rst_n), .tick(tick_10), .async_in(btn1_raw), .level(), .rise_pulse(b1));
    debounce #(.CNT(5)) db_b2  (.clk(clk_50m), .rst_n(rst_n), .tick(tick_10), .async_in(btn2_raw), .level(), .rise_pulse(b2));
    debounce #(.CNT(5)) db_b3  (.clk(clk_50m), .rst_n(rst_n), .tick(tick_10), .async_in(btn3_raw), .level(), .rise_pulse(b3));

    wire manual_evt = b0 | b1 | b2 | b3;

    // ---------------------------------------------------------
    // 3. UART Remote Overrides Parsing Subsystem
    // ---------------------------------------------------------
    wire [7:0] rx_byte;
    wire rx_valid;
    
    uart_rx #(.CLK_HZ(50_000_000), .BAUD_RATE(115200)) com_rx (
        .clk(clk_50m),
        .rst_n(rst_n),
        .rx(uart_rx_pin),
        .rx_stb(rx_valid),
        .rx_data(rx_byte)
    );

    // Protocol state-registers interpreting simple incoming commands: 
    // Frame format from host: [CMD_BYTE] [VAL_BYTE].
    // CMD_BYTE: [7:4] - Empty, [3] - Strobe trigger, [2:0] - Target Command Register Category selection.
    reg uart_stb_reg;
    reg [2:0] uart_type_reg;
    reg [7:0] uart_val_reg;
    
    always @(posedge clk_50m or negedge rst_n) begin
        if (!rst_n) begin
            uart_stb_reg  <= 1'b0;
            uart_type_reg <= 3'd0;
            uart_val_reg  <= 8'd0;
        end else if (rx_valid) begin
            if (rx_byte[3] == 1'b1) begin // Config Command prefix high
                uart_type_reg <= rx_byte[2:0];
                uart_stb_reg  <= 1'b1;
            end else begin
                uart_val_reg <= rx_byte;
                uart_stb_reg <= 1'b0; // Resubmits only on matching control strobe index
            end
        end else begin
            uart_stb_reg <= 1'b0;
        end
    end

    // ---------------------------------------------------------
    // 4. Core Logic / Central Command State Machine
    // ---------------------------------------------------------
    wire [7:0] dL0, dL1, dL2, dL3, dF0, dF1;
    wire [3:0] relays;
    wire alarm_state;

    // Basic Scheduler component simulating hard-coded evening / sleeping triggers:
    // Real time is run using internal frequency registers. Validated for Evening scene 3'd1.
    reg [23:0] scheduler_tick_cnt;
    reg sched_flag;
    always @(posedge clk_50m or negedge rst_n) begin
        if (!rst_n) begin
            scheduler_tick_cnt <= 0;
            sched_flag         <= 1'b0;
        end else if (tick_10) begin
            scheduler_tick_cnt <= scheduler_tick_cnt + 1;
            if (scheduler_tick_cnt == 24'd1200) begin // Virtual boundary boundary (2 min sequence step simulation scale)
                sched_flag         <= 1'b1;
                scheduler_tick_cnt <= 0;
            end else begin
                sched_flag <= 1'b0;
            end
        end
    end

    ctrl_fsm central_controller (
        .clk(clk_50m),
        .rst_n(rst_n),
        .tick_10(tick_10),
        
        .pir(pir),
        .dark(dark),
        .overcur(overcur),
        .door_open(door_open),
        .security_armed(security_armed),
        
        .manual_evt(manual_evt),
        .manual_scene_idx(manual_scene_sw),
        
        .uart_cmd_stb(uart_stb_reg),
        .uart_cmd_type(uart_type_reg),
        .uart_cmd_val(uart_val_reg),
        
        .sched_valid(sched_flag),
        .sched_scene_idx(3'd1), // Maps automatically to Evening preset scene representation
        
        .dutyL0(dL0), .dutyL1(dL1), .dutyL2(dL2), .dutyL3(dL3),
        .dutyF0(dF0), .dutyF1(dF1),
        .relays(relays),
        .alarm_active(alarm_state),
        .current_mode(state_indicators),
        .energy_saving_timer()
    );

    // ---------------------------------------------------------
    // 5. Outputs: PWM and Relays Drive Lines
    // ---------------------------------------------------------
    pwm8 driver_L0 (.clk(clk_50m), .rst_n(rst_n), .tick_1k(tick_1k), .duty(dL0), .out(L0_PWM));
    pwm8 driver_L1 (.clk(clk_50m), .rst_n(rst_n), .tick_1k(tick_1k), .duty(dL1), .out(L1_PWM));
    pwm8 driver_L2 (.clk(clk_50m), .rst_n(rst_n), .tick_1k(tick_1k), .duty(dL2), .out(L2_PWM));
    pwm8 driver_L3 (.clk(clk_50m), .rst_n(rst_n), .tick_1k(tick_1k), .duty(dL3), .out(L3_PWM));

    pwm8 driver_F0 (.clk(clk_50m), .rst_n(rst_n), .tick_1k(tick_1k), .duty(dF0), .out(F0_PWM));
    pwm8 driver_F1 (.clk(clk_50m), .rst_n(rst_n), .tick_1k(tick_1k), .duty(dF1), .out(F1_PWM));

    assign relays_out   = relays;
    assign alarm_buzzer = alarm_state;

    // Safe dummy UART Transmitter telemetry generator
    assign uart_tx_pin  = uart_rx_pin;

endmodule
