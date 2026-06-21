## =========================================================================
## Constraints File: constraints.xdc
## Target Board: Nexys A7 (XC7A100T-1CSG324C / XC7A50T)
## Smart Home Automation FPGA Controller Port Assignments
## =========================================================================

## Master Clock Resource (100 MHz oscillator)
set_property -dict { PACKAGE_PIN E3    IOSTANDARD LVCMOS33 } [get_ports { clk_50m }];
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports { clk_50m }];

## Master Software Reset Button
set_property -dict { PACKAGE_PIN C12   IOSTANDARD LVCMOS33 } [get_ports { rst_btn }];

## Physical Sensor Input Pins (Mapped to slide switches / PMOD Header JA)
set_property -dict { PACKAGE_PIN J15   IOSTANDARD LVCMOS33 } [get_ports { pir_raw }];            # Switch SW0
set_property -dict { PACKAGE_PIN L16   IOSTANDARD LVCMOS33 } [get_ports { ldr_dark_raw }];       # Switch SW1
set_property -dict { PACKAGE_PIN M13   IOSTANDARD LVCMOS33 } [get_ports { overcur_raw }];        # Switch SW2
set_property -dict { PACKAGE_PIN R15   IOSTANDARD LVCMOS33 } [get_ports { door_open_raw }];      # Switch SW3
set_property -dict { PACKAGE_PIN R17   IOSTANDARD LVCMOS33 } [get_ports { security_armed_raw }]; # Switch SW4

## Manual Interactive Room Debounce Swithes 
set_property -dict { PACKAGE_PIN M17   IOSTANDARD LVCMOS33 } [get_ports { btn0_raw }];           # Button Right
set_property -dict { PACKAGE_PIN P17   IOSTANDARD LVCMOS33 } [get_ports { btn1_raw }];           # Button Down
set_property -dict { PACKAGE_PIN N17   IOSTANDARD LVCMOS33 } [get_ports { btn2_raw }];           # Button Center
set_property -dict { PACKAGE_PIN P18   IOSTANDARD LVCMOS33 } [get_ports { btn3_raw }];           # Button Left

## Switch Board Manual Scene Selectors SW13-SW15
set_property -dict { PACKAGE_PIN U12   IOSTANDARD LVCMOS33 } [get_ports { manual_scene_sw[0] }]; # SW13
set_property -dict { PACKAGE_PIN U11   IOSTANDARD LVCMOS33 } [get_ports { manual_scene_sw[1] }]; # SW14
set_property -dict { PACKAGE_PIN V10   IOSTANDARD LVCMOS33 } [get_ports { manual_scene_sw[2] }]; # SW15

## PMOD Connector JB for UART ESP32 Bridge communication
set_property -dict { PACKAGE_PIN D14   IOSTANDARD LVCMOS33 } [get_ports { uart_rx_pin }];        # PMOD JB PIN 1
set_property -dict { PACKAGE_PIN F16   IOSTANDARD LVCMOS33 } [get_ports { uart_tx_pin }];        # PMOD JB PIN 2

## Actuator PWM Out lines (Mapped to PMOD Header JC / status onboard LEDs)
set_property -dict { PACKAGE_PIN K1    IOSTANDARD LVCMOS33 } [get_ports { L0_PWM }];             # JC PIN 1 (Light 0)
set_property -dict { PACKAGE_PIN F6    IOSTANDARD LVCMOS33 } [get_ports { L1_PWM }];             # JC PIN 2 (Light 1)
set_property -dict { PACKAGE_PIN J2    IOSTANDARD LVCMOS33 } [get_ports { L2_PWM }];             # JC PIN 3 (Light 2)
set_property -dict { PACKAGE_PIN G6    IOSTANDARD LVCMOS33 } [get_ports { L3_PWM }];             # JC PIN 4 (Light 3)

set_property -dict { PACKAGE_PIN E7    IOSTANDARD LVCMOS33 } [get_ports { F0_PWM }];             # JC PIN 7 (Fan 0)
set_property -dict { PACKAGE_PIN J3    IOSTANDARD LVCMOS33 } [get_ports { F1_PWM }];             # JC PIN 8 (Fan 1)

## High Voltage Electrical Solid State Relay Lines (Mapped to lower header mappings JD)
set_property -dict { PACKAGE_PIN H4    IOSTANDARD LVCMOS33 } [get_ports { relays_out[0] }];      # Socket Relay 0
set_property -dict { PACKAGE_PIN H1    IOSTANDARD LVCMOS33 } [get_ports { relays_out[1] }];      # Socket Relay 1
set_property -dict { PACKAGE_PIN G1    IOSTANDARD LVCMOS33 } [get_ports { relays_out[2] }];      # Socket Relay 2
set_property -dict { PACKAGE_PIN G3    IOSTANDARD LVCMOS33 } [get_ports { relays_out[3] }];      # Socket Relay 3

## Physical Piezo Alarm Buzzer / Warning Led mapping
set_property -dict { PACKAGE_PIN H17   IOSTANDARD LVCMOS33 } [get_ports { alarm_buzzer }];       # Led LD0 / JC PIN 9

## State indicator status registers mapping to main board rgb lights
set_property -dict { PACKAGE_PIN K15   IOSTANDARD LVCMOS33 } [get_ports { state_indicators[0] }]; # LD1
set_property -dict { PACKAGE_PIN J13   IOSTANDARD LVCMOS33 } [get_ports { state_indicators[1] }]; # LD2

## Standard power optimization and timing variables
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]
set_property CONFIG_MODE SPIx4 [current_design]
