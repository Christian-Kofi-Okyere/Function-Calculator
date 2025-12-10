# Function Calculator 

Author: Christian Okyere

Date: 2012 (source timestamps)

## Overview

This repository implements a small RPN-style calculator in VHDL targeted at Altera/Intel FPGAs (Cyclone III). The design includes:

- `calculator.vhd` — top-level Moore state machine that implements the calculator control and datapath.
- `memram.vhd` — wizard-generated single-port RAM (Altera `altsyncram`) used as a small stack/memory (16 × 8-bit words).
- `hexdisplay.vhd` — 4-bit to 7-segment decoder used to drive two 7-seg digits.
- `calculatorDiag.bdf` — block-diagram file (Quartus Block Editor) describing top-level I/O and wiring.
- Additional artifacts: student report `CS232 - Project6 Report.pdf` and demo videos (addition.mp4, subtraction.mp4, etc.).

The top-level `calculator` entity exposes push/capture/operate controls and two 7-segment outputs. The design demonstrates finite-state-machine control, simple stack memory usage, and basic arithmetic operations (add, subtract, multiply low nibbles, and an exponential routine implemented by repeated multiplication).

## Quick component summary

- `calculator.vhd` (top-level)
  - Ports
    - clock: in std_logic
    - b0: in std_logic  -- Capture input (push/capture behavior)
    - b1: in std_logic  -- Enter (write to RAM)
    - b2: in std_logic  -- Action (pop/compute)
    - op: in std_logic_vector(1 downto 0) -- operation select switches
    - data: in std_logic_vector(7 downto 0) -- input data/switches
    - digit0: out std_logic_vector(6 downto 0) -- 7-seg for low nibble / result
    - digit1: out std_logic_vector(6 downto 0) -- 7-seg for high nibble / result
  - Internal
    - Instantiates `memram` (address width 4 bits, 16 words of 8 bits)
    - Instantiates two `hexdisplay` instances: one for bits [3:0] and one for [7:4] of the result register (`mbr`).
    - Implements a 4-state (extended) Moore-style FSM with states encoded as 3-bit vectors (examples: "000", "001", ..., "111").
    - Has an accumulator-like register `mbr`, a `holder` (16-bit intermediate register) and a `counter` used for exponentiation loops.
  - Notable behavior
    - `b0` when asserted captures `data` into `mbr` (prepare value).
    - `b1` writes `mbr` into RAM at `stack_ptr` and increments the stack pointer.
    - `b2` triggers a pop (decrement pointer) and sets up an operation path using the `op` switches.
    - Operation codes (in `calculator.vhd`):
      - default/"00": addition (RAM_output + mbr)
      - "01": subtraction (RAM_output - mbr)
      - "10": multiplication using the low 4 bits of operands
      - others: a branch leading to an exponentiation routine that multiplies repeatedly using `holder` and `counter`.

- `memram.vhd`
  - Wizard-generated `altsyncram` module.
  - Parameters: single-port, 16 words × 8 bits, output registered on clock, intended family Cyclone III.
  - Ports: `address` (4 bits), `clock`, `data` (8 bits), `wren`, `q` (8 bits).
  - Simulation requires the Altera/Intel `altera_mf` library.

- `hexdisplay.vhd`
  - Small combinational decoder mapping 4-bit input to 7-seg patterns (outputs are active-high booleans for segments 0..6).
  - Input type: 4-bit `UNSIGNED` (entity uses UNSIGNED type for convenience) and 7-bit `UNSIGNED` output for segments.

- `calculatorDiag.bdf`
  - Block diagram with named pins for all inputs/outputs (clk, b0, b1, b2, data[7:0], op[1:0], digit0[6:0], digit1[6:0]).
  - Useful when wiring to a board-level pin assignment file in Quartus.

## How it works — short technical notes

The calculator is implemented as a Moore FSM. The high-level flow is:

1. Idle state: waits for control inputs.
2. Capture (`b0`) stores the `data` switch value into `mbr` (memory buffer register).
3. Enter (`b1`) writes `mbr` into `memram` at `stack_ptr`, sets `RAM_we` for a cycle, and updates `stack_ptr`.
4. Action (`b2`) pops the top of stack into `counter` and/or `RAM_output` and advances through states to perform the selected operation.
5. Result is written to `mbr` and displayed via two `hexdisplay` instances (low and high nibble mapped separately to `digit0` and `digit1`).

Exponentiation is implemented by repeated multiplication via a loop that uses `holder` (16 bits) and `counter` as loop iterations. Multiplication for the normal multiply operation uses only low nibble multiplication (both operands' low 4 bits), so be aware of limited range.

## Simulating and Synthesizing

Suggested toolchain: Quartus II (12.x era stamps are present in the generated megafunction) or a modern Intel Quartus version that still supports Cyclone III. For simulation use ModelSim-Altera or ModelSim with the Altera libraries.

Simulation tips:
- Add `memram.vhd`, `hexdisplay.vhd`, and `calculator.vhd` to the simulation project.
- Make sure the `altera_mf`/`altera` libraries are compiled and available for the `memram` megafunction. In ModelSim you may need to compile the Intel/Altera simulation library (or use the library distributed with Quartus).
- Stimulate signals (clock, b0/b1/b2, op, data) manually or with a testbench to reproduce the demo videos.

Synthesis notes:
- Open the block diagram `calculatorDiag.bdf` in Quartus if you intend to use the GUI for pin assignment and top-level wiring.
- The `memram.vhd` megafunction is already parametrized for Cyclone III; if you retarget to another family, regenerate or adjust the megafunction parameters.
- No pin assignments are included in this repo — add a `.qsf` or use the Quartus Pin Planner to map `b0`, `b1`, `b2`, `data[]`, `op[]`, `digit0[]`, `digit1[]` to board pins.

Example (optional) command-line flow (adapt to your Quartus/ModelSim install):

# Compile Quartus project (if you have a `.qpf`/`.qsf`)
quartus_sh --flow compile <project_name>

# Run a ModelSim simulation (example idea):
# 1. compile all VHDL sources plus altera libraries
# 2. run vsim on a testbench that toggles clock and control signals

Note: the exact commands depend on your local Quartus/ModelSim installation and project files.

## I/O and user operation (how to use the design on hardware)

- Configure 8-bit `data` switches to the desired operand.
- Press `b0` to capture the `data` value into `mbr`.
- Press `b1` to push `mbr` into RAM (stack) — this increments `stack_ptr`.
- Press `b2` to pop and perform the operation selected by `op`:
  - `op = "00"` (default): addition
  - `op = "01"`: subtraction
  - `op = "10"`: multiply (low 4 bits)
  - other values: branch to exponential routine (multiply `RAM_output` repeatedly)

Results are presented on two 7-segment displays (`digit0` shows lower nibble, `digit1` shows upper nibble of `mbr`).

## Known limitations & edge cases

- Arithmetic width is 8 bits; overflow behavior is not explicitly handled. High-byte results may be truncated.
- The dedicated multiply operation multiplies only the low 4 bits of operands — this limits correctness for full 8-bit multiplication.
- The exponentiation routine uses `counter` and iterative multiplication; check `counter` width/initialization for large exponents.
- No debounce logic for push-buttons; for hardware usage consider adding debouncing.
- `memram.vhd` is a vendor-generated file and requires the Altera simulation/synthesis support files.

## Suggested improvements

- Add a simple testbench (VHDL) that exercises the main operations and checks the `mbr` result automatically.
- Add proper pin assignment `.qsf` and a top-level constraints file for a target dev board.
- Add button debouncing and an input-ready handshake for more robust human interaction.
- Replace low-nibble multiply with full 8-bit multiply if resource budget allows.

## Licensing & credits

- `memram.vhd` contains Altera/Intel megafunction wizard headers. Respect the Altera/Intel licensing terms when using those files.
- The rest of the code appears to be course/student work (author header in VHDL source: Christian Okyere). Include your preferred OSS license file if you intend to publish (MIT, Apache-2.0, etc.).

## Files

- `calculator.vhd` — top-level FSM and datapath.
- `memram.vhd` — generated Altera single-port RAM (16×8).
- `hexdisplay.vhd` — 4→7 segment decoder.
- `calculatorDiag.bdf` — Quartus block diagram representation of top-level I/O.
- `CS232 - Project6 Report.pdf` — project write-up (useful for details and verification).