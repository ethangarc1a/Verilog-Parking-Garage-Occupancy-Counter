# Smart Parking Garage Controller in Verilog

A Moore FSM-based Verilog project that simulates a smart parking garage controller with ticket issuance, ticket validation, payment-gated exit, occupancy tracking, and error handling.

## Overview

This project models a parking garage system with:

- one entry lane
- one exit lane
- ticket issuance at entry
- ticket validation at exit
- payment required before exit gate opens
- occupancy tracking for up to 100 cars
- full-lot detection
- invalid/reused ticket detection
- alarm signaling
- admin override that behaves like a full system reset

The design is split into multiple Verilog modules to keep control logic and data handling organized.

## Highlights

- **Moore FSM control** for clean state-based behavior
- **Modular Verilog design** with separate controller, ticket manager, and occupancy counter
- **Ticket lifecycle handling** from issuance to reuse prevention
- **Payment-gated exit flow** before gate release
- **Occupancy accounting** with remaining-space tracking
- **Error handling** for invalid and reused tickets
- **Waveform-based verification** in GTKWave with scenario-driven testbench coverage

## Module Breakdown

### `parking_garage_top`
Top-level module that connects all submodules.

### `parking_controller_fsm`
Main Moore FSM controller for:
- entry sequence
- exit sequence
- payment wait
- full/alarm handling

### `ticket_manager`
Handles:
- issuing new ticket IDs
- storing issued tickets
- tracking used tickets
- reporting whether a scanned ticket is valid

### `occupancy_counter`
Handles:
- current occupancy count
- remaining spaces
- full-lot status

## Parameters

- `CAPACITY = 100`
- `TICKET_WL = 8`
- `COUNT_WL = 7`

## FSM Overview

### Entry Path
`IDLE -> ENTRY_DETECT -> CHECK_SPACE -> ISSUE_TICKET -> OPEN_ENTRY_GATE -> WAIT_ENTRY_PASS -> CLOSE_ENTRY_GATE -> UPDATE_COUNT_IN -> IDLE`

### Exit Path
`IDLE -> EXIT_DETECT -> WAIT_TICKET_SCAN -> VALIDATE_TICKET -> WAIT_PAYMENT -> PAYMENT_APPROVED -> OPEN_EXIT_GATE -> WAIT_EXIT_PASS -> CLOSE_EXIT_GATE -> UPDATE_COUNT_OUT -> MARK_TICKET_USED -> IDLE`

### Invalid Ticket Path
`VALIDATE_TICKET -> INVALID_TICKET -> ALARM -> IDLE`

### Full Garage Path
`CHECK_SPACE -> FULL -> IDLE`

## Key Signals

### Inputs
- `CLK`
- `RESET`
- `admin_override`
- `entry_sensor`
- `entry_passed`
- `exit_sensor`
- `exit_passed`
- `scan_ticket`
- `ticket_in[7:0]`
- `payment_done`

### Outputs
- `entry_gate_open_cmd`
- `entry_gate_close_cmd`
- `exit_gate_open_cmd`
- `exit_gate_close_cmd`
- `ticket_out[7:0]`
- `garage_full`
- `invalid_ticket`
- `alarm`
- `occupancy_count[6:0]`
- `spaces_remaining[6:0]`

## Testbench Coverage

The testbench verifies:
- reset behavior
- successful entry
- successful valid exit
- invalid ticket detection
- reused ticket rejection
- admin override reset behavior

## Example Waveform Highlights

### Successful Entry / Occupancy Update
This waveform shows the FSM progressing through the normal entry path, issuing a ticket, opening/closing the entry gate, and updating occupancy from 0 to 1.

![Successful entry waveform](assets/waveform_success.png)

### Invalid / Reused Ticket Error Path
This waveform shows the controller rejecting a bad ticket and asserting the alarm path.

![Error path waveform](assets/waveform_error_path.png)

## How to Run

Compile the design and testbench with your Verilog simulator, then run the simulation and inspect the generated waveform in GTKWave.

Typical flow:
1. compile `main.v` and the testbench file
2. run the simulation
3. open the generated `.vcd` waveform file in GTKWave

## File Structure

```text
.
├── main.v
├── tb_parking_garage.v
├── assets
│   ├── waveform_success.png
│   └── waveform_error_path.png
└── README.md
