# Smart Home Automation System on FPGA

[![Verilog](https://img.shields.io/badge/Language-Verilog_HDL-32ccff.svg?style=for-the-badge&logo=verilog&logoColor=white)](https://en.wikipedia.org/wiki/Verilog)
[![FPGA Target](https://img.shields.io/badge/FPGA_Target-Xilinx_Artix--7-ff6600.svg?style=for-the-badge&logo=xilinx&logoColor=white)](https://www.xilinx.com/products/silicon-devices/fpga/artix-7.html)
[![Simulation](https://img.shields.io/badge/Simulation-Icarus_Verilog_/_Vivado_Simulator-brightgreen.svg?style=for-the-badge&logo=cpu&logoColor=white)](http://iverilog.icarus.com/)
[![License](https://img.shields.io/badge/License-MIT-green.svg?style=for-the-badge)](LICENSE)

A high-reliability, hard-real-time Smart Home Automation and Electrical Safety System fully engineered in **Synthesizable Verilog HDL**. This design utilizes a highly deterministic **Finite State Machine (FSM)** core alongside specialized peripherals, synchronous timing subgrids, and noise-immune sensor conditioning stages. It targets a physical AMD/Xilinx Artix-7 FPGA (specifically the Nexys A7 development board) to deliver concurrent control, microsecond reaction times, and absolute safety isolating loops that outperform traditional software-based microcontroller implementations (e.g., Arduino, ESP32) under safety-critical conditions.

---

## Technical Architecture Overview

Modern home automation setups are heavily dependent on microcontrollers running sequential firmware loops. Under heavy sensor loads, serial routing operations, or crash-inducing stack overflows, these devices introduce non-deterministic latency spikes or lock up entirely.

This FPGA-based design guarantees **deterministic hardware parallelism**:
*   **Zero-Overhead Concurrency:** All sensors, clock strobes, and PWM channels run simultaneously in dedicated, isolated logic fabrics.
*   **Nanosecond-Scale Trip Latency:** Safety-critical protection (such as overcurrent circuit breaker isolation) bypasses the central state scheduler to assert instantly.
*   **Metastability & Debounce Safeguards:** All external physical switch contacts and asynchronous sensor inputs are cleaned using dual-stage latch synchronizers and synchronous debouncers.
*   **Dual Single-Clock Domains:** All submodules run off a shared high-speed global low-skew board clock (e.g., 50 MHz or 100 MHz), utilizing single-cycle clock-enable ticks rather than dangerous multiple physical PLL clocks, preventing hazardous clock-domain crossing (CDC) issues.

---

## Directory Structure & Folder Decomposition

This repository is optimized for standard professional FPGA design suite imports (e.g., Xilinx Vivado, Intel Quartus, or open-source Icarus/Yosys chains). The organization is as follows:

```
Smart-Home-Automation-FPGA/
│
├── rtl/                   # Synthesizable RTL (Register Transfer Level) Verilog source files
│   ├── clk_en.v           # Timing strobe generator (1 kHz and 10 Hz ticks)
│   ├── debounce.v         # Dual FF synchronizer & count accumulator debouncer
│   ├── ctrl_fsm.v         # Main multi-priority, Moore-type State Sequencer
│   ├── pwm8.v             # 8-bit Pulse-Width Modulation (PWM) duty driver
│   ├── scenes.v           # LUT (Look-Up Table) holding preset room profiles
│   ├── uart_rx.v          # Noise-filtered 16x oversampling 115200 Baud receiver
│   └── top.v              # Structural top binder of the hardware pins and paths
│
├── tb/                    # Verification suites & testbenches
│   └── home_tb.v          # Multi-scenario automated simulation verification bench
│
├── constraints/           # Physical pinout and IO mappings
│   └── constraints.xdc    # Xilinx Design Constraints mapping targeting the Nexys A7
│
├── simulation/            # Verification configurations and synthesis tooling files
│   └── synth.ys           # Yosys open-source RTL logic gate map synthesis script
│
├── waveforms/             # Saved waveform simulation trace outputs (VCD, WDB files)
├── reports/               # Toolchain utilization, timing constraints, and power reports
├── images/                # Block diagrams, FSM charts, and UI hardware setup graphics
└── docs/                  # Architectural documentations and external sensor datasheets
```

### Detailed Folder Explanations

1.  **`rtl/`**: Holds the synthesizable hardware description. Every module is highly modular and documented with inline comments to explain register assignments and edge-detectors.
2.  **`tb/`**: Contains the testing framework. The `home_tb.v` simulates all physical triggers (motion, ambient shifts, overcurrent, magnetic contacts, and manual button presses) and asserts timing integrity under hostile conditions.
3.  **`constraints/`**: Holds the `constraints.xdc` file. This tells the synthesizer compiler which physical balls/pins of the Artix-7 chip to route to standard peripherals, sliding switches, status LEDs, and expansion headers on the Nexys board.
4.  **`simulation/`**: Houses compilation files, specifically Yosys scripts to confirm gate-level synth capabilities and structural integrity outside of bulky proprietary tools.
5.  **`waveforms/`**: Saved interactive simulation traces. You can load these `.vcd` files inside GTKWave or Vivado Waveform Analyzer to inspect raw signal edges down to the nanosecond scale.
6.  **`reports/`**: Logs resource utilization profiles (registers, LUTs, DSP slices, IO buffers), timing margins (slack, setup, and hold parameters), together with thermal power calculations showing typical low-power FPGA operations.
7.  **`images/`**: Contains asset directories for visual references in markdown and project portfolios.
8.  **`docs/`**: Holds developer sheets, including magnetic contact schematics, LDR voltage divider ratios, and UART host communication guidelines.

---

## Hardware Block Diagram

The structural routing of files within the `rtl/` directory is mapped hierarchically through the `top.v` file as illustrated below:

```
                  +--------------------------------------------------------+
                  |                     top.v (TOP Layer)                  |
                  |                                                        |
+-------------+   |   +------------+                                       |
|  CLK_50M    |------>|  clk_en.v  |-- tick_1k (1kHz) ----------------+    |
+-------------+   |   |            |-- tick_10 (10Hz) -------------+  |    |
                  |   +------------+                               |  |    |
                  |                                                |  |    |
+-------------+   |   +------------+                               |  |    |   +-------------------+
| SENSORS /   |   |   | debounce.v |                               |  |    |-->|     pwm8.v        |---> L[3:0]_PWM
| SWITCHES    |------>|            |--- level / edge --------------|--|---|   |   Light Dimmer    |     (LED Dimming)
+-------------+   |   | (x9 inst)  |                               |  |   |   +-------------------+
                  |   +------------+                               |  |   |
                  |                                                v  |   |   +-------------------+
+-------------+   |   +------------+     +-------------------+     |  |   |-->|     pwm8.v        |---> F[1:0]_PWM
| UART RX Pin |------>| uart_rx.v  |---->| ctrl_fsm.v        |<----+--|---|   |    Fan Speed      |     (MOSFET gate)
+-------------+   |   | 115200 8N1 |     | Moore FSM controller|      |   |   +-------------------+
                  |   +------------+     |  Mode Priority:   |      |   |
                  |                      |  1. S_ALARM       |      v   |   +-------------------+
                  |                      |  2. S_MANUAL      |------+---|-->| relays_out [3:0]  |---> (High voltage
                  |                      |  3. S_AUTO        |          |   | Sockets switches  |      Solid State)
                  |                      |  4. S_SCHEDULE    |          |   +-------------------+
                  |                      +-------------------+          |
                  |                                |                    |   +-------------------+
                  |                                +--------------------+-->| alarm_buzzer      |---> (Piezo Horn)
                  |                                                         +-------------------+
                  +--------------------------------------------------------+
```

---

## Logic Priority & Finite State Machine (FSM)

The central operational state register is a fully synchronous Moore-type FSM containing four highly responsive operational states. It guarantees continuous sensor surveillance with hard-coded logic paths, establishing an absolute, non-preemptible sequence.

### Priority Level Table
| Mode Status | State Name | Sensor Triggers | Logic Priority | Electrical Safety Rules | Outputs Mapped |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **CRITICAL** | `S_ALARM` | `overcur` **OR** (`security_armed` **AND** `door_open`) | **1 (Highest)** | Isolates all output socket relays. Trips buzzer alarms. Strobe lights in event of burglar, or turns lights complete OFF on overcurrent. | Buzzer: ON, Relays: OFF, Fans: OFF |
| **INTERACTIVE**| `S_MANUAL` | `manual_evt` (debounced buttons) **OR** UART remote override | **2** | Allows direct switch-board scene overrides or precise host register overrides. Bypasses schedules. | Lookup LUT values / UART Register values |
| **DYNAMIC** | `S_AUTO` | `pir` == 1 **AND** `dark` == 1 | **3** | Dynamic lighting control. Restarts a 60-second energy-saving cooldown timer on continuous motion. | L0 dimmers soft bright. Sockets active. |
| **DEFAULT** | `S_SCHEDULE`| Time trigger boundary match (automatic) | **4 (Lowest)** | Schedules control load coordinates (Preset Night layouts/Morning layouts) automatically. | Preset Scene Indexes |

### FSM State Transition diagram

```
                         +-----------------------------+
                         |                             |
                         |           +-------------+   |  [overcur == 1]
                         |           |   RESET    |   |  [security_armed & door_open]
                         |           +-------------+   |
                         |                  |          |
                         v                  v          v
                 +---------------------------------------------+
                 |                 S_ALARM                     |
                 +---------------------------------------------+
                        |                             ^
                        | [overcur == 0 &&           | [overcur_raw == 1]
                        |  intruder_safe &&            | [security_armed & door_open]
                        |  manual_evt == 1]           |
                        v                             |
          +--------------------> +-------------------------+ <-------------------+
          |                      |        S_MANUAL         |                        |
          |                      +-------------------------+                        |
          |                        /                     \                          |
          |        [pir & dark && /                       \ [sched_valid &&         |
          |         !manual_evt] /                         \ !manual_evt]           |
          |                     v                           v                       |
   [manual_evt ||        +------------+               +------------+         [manual_evt ||
    uart_cmd_stb]        |   S_AUTO   | ------------> | S_SCHEDULE |          uart_cmd_stb]
          |              +------------+  [idle_cnt==0 &+------------+               |
          |                    ^         !pir]              |                       |
          |                    |                            |                       |
          |                    +----------------------------+                       |
          |                              [pir & dark]                               |
          +-------------------------------------------------------------------------+
```

---

## Simulated Graphical Timing Charts

These standard ASCII timing charts document system performance during critical testbench simulation scenarios:

### 1. Robust Input Debouncing (Switch Noise Isolation)

High-transient contact noise from raw physical toggle switches is entirely ignored, preventing logic glitches in underlying modules.

```
                  _   _       _     __________________________________________
async_in     ____| |_| |_____| |___|
                        ________________________
s2 (Sync)    __________|                        \_____________________________
                                                   :<- debounce delay (CNT=5) ->:
                                                   +----------------------------+
level (Out)  ______________________________________|                            |_____
                                                   _
rise_pulse   ____________________________________||___________________________________
```

### 2. Auto-Lighting Transition Cycle (Sensor Mode + 60s Idle Cooldown Timer)

Monitors the smooth fade-in and dim-down energy preservation curves. A watchdog counter count tracking at 10 Hz ticks handles room clearings.

```
               _____________________________
pir          _|                             \_________________________________
             ______
dark         |     \__________________________________________________________
                                             :<--- 600 Tick Cooldown Timer --->:
             +------------------------------+
state_ind    | S_SCHEDULE (01)  | S_AUTO(10)| S_AUTO (Counting countdown down) | S_SCHEDULE (01)
             +------------------------------+                                  +------
                 +--------------------------+
L0_PWM (Dim) ____|    Soft Bright (180)     |==================================\______
             ____:                          :                                  :______
relays_out   ____|[Entrance Relays Live]    |==================================\______
```

### 3. Quick-Trip Overcurrent circuit breaker safety-breaker

Shows how a severe circuit trip interrupts active operations, instantly shutting down external power relays to prevent hardware fires.

```
                                               * CRITICAL FAULT EVENT
                                               |
                                               v
overcur_raw   _________________________________+==============================
                                               :<- Tripping Latency (< 20ns) :
state_ind     [------- S_MANUAL (00) ----------|------------ S_ALARM (11) -----
              _________________________________
relays_out    _________________________________|\_____________________________ (Isolate all Relays)
                                               :
L0_PWM (Dim)  ========= Mapped Dim Level =======|\_____________________________ (Isolate Lights)
                                               :
alarm_buzzer  _________________________________+============================== (Deploy Piezo siren)
```

---

## Toolchain & Synthesis Walkthrough

There are two primary methods to build, simulate, and generate bitstreams for this hardware.

### Option A: Professional AMD/Xilinx Vivado Suite (Recommended)

1.  **Launch Vivado IDE** and create a new project targeting chip `xc7a50tcsg324-1` (Nexys A7-50T) or `xc7a100tcsg324-1`.
2.  **Add Source Files** from this repository's `rtl/` directory. Set `top.v` as the Top module of the project hierarchy.
3.  **Add Simulation Testbench** from `tb/home_tb.v`.
4.  **Add Constraint Mapping File** from `constraints/constraints.xdc`.
5.  **Run Behavioral Simulation**: Click "Run Simulation" -> "Run Behavioral Simulation". Validate transitions matching the trace shapes outlined in the timing charts section.
6.  **Synthesize, Implement & Compile Bitstream**: Click "Generate Bitstream" in Vivado Flow Navigator. It runs synthesis optimization, maps look-up tables to actual Artix slice coordinates, confirms routing setups, and writes a target binary bitstream (e.g., `top.bit`).
7.  **Program Hardware**: Connect the Nexys board via micro-USB, open Vivado Hardware Manager, auto-connect, right-click your FPGA device, and select "Program Board" using the compiled bitstream.

### Option B: Open-Source Command Line Pipeline (GCC Style)

Ensure you have `compiler tools`, `icarus-verilog`, `yosys`, and `gtkwave` installed on your machine.

#### 1. Simulation and Waveforms Verification
```bash
# Compile synthesizable design alongside testbench layout components
iverilog -o home_sim tb/home_tb.v rtl/*.v

# Execute simulation to dump real nanosecond trace data
vvp home_sim

# Launch GTKwave to visually inspect timing charts interactively
gtkwave home_tb.vcd &
```

#### 2. RTL Synthesis & Gate Mapping (Using Yosys)
```bash
# Execute compilation script using Yosys engine to mapping custom Artix-7 gate logic
yosys -s simulation/synth.ys
```
*Successfully compiled netlists will be output as structural layout JSON files mapping gate components directly.*

---

## Remote Interface Communication (UART Protocol Specification)

The smart home controller receives commands from an external microcontroller (e.g. ESP32, Raspberry Pi, or USB-UART bridge) running at `115200 Baud, 8-N-1` settings.

### Frame Layout Architecture
To command the FPGA registers, the host must transmit a sequence of 2 bytes:
1.  **Byte 1: Command Control Header (`[CMD_BYTE]`)**
    *   Bits `[7:4]`: Constant padding `0000`
    *   Bit `[3]`: Strobe command identifier (Must be `1` to signal a write process)
    *   Bits `[2:0]`: Target register address index (0..7):
        *   `1`: Target room light 0 dimmer register
        *   `2`: Target room light 1 dimmer register
        *   `3`: Target room light 2 dimmer register
        *   `4`: Target room light 3 dimmer register
        *   `5`: Target Fan speed 0 register
        *   `6`: Target Fan speed 1 register
        *   `7`: Target Electrical Relay direct mask override
2.  **Byte 2: Parameter Payload Value (`[VAL_BYTE]`)**
    *   Holds an 8-bit unsigned integer value (0..255). For address index `7` (Relays), bits `[3:0]` map directly to the four high power Solid-State Relay actuators on/off states.

This ensures simple, noise-immune custom interfaces can override physical switches and run cloud integrations (such as Apple HomeKit, Google Home, or Home Assistant) while maintaining hardware-level guarantees internally on the FPGA.

---

## Contributions and Verification License

This FPGA controller project is open-sourced under the **MIT License**. Contributions relating to PMOD sensor interfaces (such as DHT22 temperature streams, I2C digital compasses, or SPI LCD status panels) are welcome!
