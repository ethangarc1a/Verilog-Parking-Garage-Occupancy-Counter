// Ethan Garcia
// Smart Parking Garage Controller

// Modules:
//   1) occupancy_counter
//   2) ticket_manager
//   3) parking_controller_fsm
//   4) parking_garage_top

// 1) OCCUPANCY COUNTER

// Purpose:
// - Track how many cars are currently inside the garage
// - Track how many spaces remain
// - Assert full flag when occupancy reaches CAPACITY

module occupancy_counter #(
    parameter CAPACITY = 7'd100,
    parameter COUNT_WL = 7
)(
    input CLK,
    input RESET,   // use reset_all from top module
    input inc_count,
    input dec_count,

    output reg [COUNT_WL-1:0] occupancy_count,
    output reg [COUNT_WL-1:0] spaces_remaining,
    output reg garage_full_internal
);

    // Next-value registers
    // These are useful if you want a clean next-value style
    reg [COUNT_WL-1:0] next_occupancy_count;
    reg [COUNT_WL-1:0] next_spaces_remaining;
    reg next_garage_full_internal;


    // Sequential block
    always @(posedge CLK or posedge RESET) begin
        if (RESET) begin
            occupancy_count <= 7'd0;
            spaces_remaining <= CAPACITY;
            garage_full_internal <= 1'b0;
        end
        else begin
            occupancy_count <= next_occupancy_count;
            spaces_remaining <= next_spaces_remaining;
            garage_full_internal <= next_garage_full_internal;
        end
    end

    // Combinational next-value logic

    always @(*) begin
    // initial defaults
    // no unintended latches
    next_occupancy_count = occupancy_count;
    next_spaces_remaining = spaces_remaining;
    next_garage_full_internal = garage_full_internal;

    // increment case
    if ((occupancy_count < CAPACITY) && (inc_count == 1'b1) && (dec_count == 1'b0)) begin // occupancy < 100 and inc_count = 1 and dec_count = 0
        next_occupancy_count = occupancy_count + 1'b1;
    end

    // decrement case
    else if ((occupancy_count > 0) && (inc_count == 1'b0) && (dec_count == 1'b1)) begin // as long as occupancy > 0 , we are able to decrement count
        next_occupancy_count = occupancy_count - 1'b1;
    end

    // recompute derived values
    next_spaces_remaining = CAPACITY - next_occupancy_count; // remaining parking spots left
    next_garage_full_internal = (next_occupancy_count == CAPACITY); // assert FULL when COUNT = 100
end
endmodule



// 2) TICKET MANAGER

// Purpose:
// - Issue ticket IDs at entry
// - Remember which tickets were issued
// - Remember which tickets were already used
// - Continuously report whether ticket_in is valid

// Ticket rule:
//   ticket_valid = issued[ticket_in] && !used[ticket_in]

module ticket_manager #(
    parameter TICKET_WL = 8
)(
    input CLK,
    input RESET,   // use reset_all from top module

    input issue_ticket_cmd,
    input mark_ticket_used_cmd,
    input [TICKET_WL-1:0] ticket_in,

    output reg [TICKET_WL-1:0] ticket_out,
    output reg ticket_valid // not a stored state value that needs to be updated on the clock
);
    // Ticket storage
    reg [TICKET_WL-1:0] next_ticket_id;
    reg issued [0:255];
    reg used [0:255];

    integer i; // Integer used for clearing arrays on reset

    // Sequential block
    always @(posedge CLK or posedge RESET) begin
        if (RESET) begin
            // reset single registers
            next_ticket_id <= 8'd0;
            ticket_out <= 8'd0;

            // clear ticket storage arrays
            for (i = 0; i < 256; i = i + 1) begin
            // for loop to zero out issued and used arrays
            issued[i] <= 1'b0;
            used[i] <= 1'b0;
        end
    end
    else begin
        if (issue_ticket_cmd) begin
            ticket_out <= next_ticket_id; // output current ticket ID
            issued[next_ticket_id] <= 1'b1; // mark ticket as ISSUED
            used[next_ticket_id] <= 1'b0;  // mark new ticket as UNUSED
            next_ticket_id <= next_ticket_id + 1'b1;  // advance to NEXT ticket ID
            end

        if (mark_ticket_used_cmd) begin
        used[ticket_in] <= 1'b1;  // mark scanned ticket as USED
    end
end
end

    // Combinational ticket validation
    always @(*) begin
    ticket_valid = 1'b0; // default ticket value = 0

    // check current scanned ticket against ticket database
    // valid if issued[ticket_in] is 1 and used[ticket_in] is 0
    if (issued[ticket_in] && !used[ticket_in]) begin
        ticket_valid = 1'b1;
    end
end
endmodule




// 3) PARKING CONTROLLER FSM

// Purpose:
// - Main Moore FSM for parking garage control
// - Controls entry flow, exit flow, payment wait, alarm/full states
// - Produces gate commands and helper-module control pulses
// Moore style

module parking_controller_fsm #(
    parameter COUNT_WL = 7
)(
    input CLK,
    input RESET,   // use reset_all from top module

    // Entry / exit inputs
    input entry_sensor,
    input entry_passed,
    input exit_sensor,
    input exit_passed,
    input scan_ticket,
    input payment_done,

    // Status inputs from helper modules
    input ticket_valid,
    input garage_full_internal,

    // Control outputs to helper modules
    output reg issue_ticket_cmd,
    output reg mark_ticket_used_cmd,
    output reg inc_count,
    output reg dec_count,

    // Gate control outputs
    output reg entry_gate_open_cmd,
    output reg entry_gate_close_cmd,
    output reg exit_gate_open_cmd,
    output reg exit_gate_close_cmd,

    // Status outputs
    output reg garage_full,
    output reg invalid_ticket,
    output reg alarm
);

    // State registers
    // 5 bits are enough for the current number of states
    reg [4:0] state, next_state;

    // Parameter states
    parameter S_IDLE = 5'd0,
              S_ENTRY_DETECT = 5'd1,
              S_CHECK_SPACE = 5'd2,
              S_ISSUE_TICKET = 5'd3,
              S_OPEN_ENTRY_GATE = 5'd4,
              S_WAIT_ENTRY_PASS = 5'd5,
              S_CLOSE_ENTRY_GATE = 5'd6,
              S_UPDATE_COUNT_IN = 5'd7,
              S_EXIT_DETECT = 5'd8,
              S_WAIT_TICKET_SCAN = 5'd9,
              S_VALIDATE_TICKET = 5'd10,
              S_INVALID_TICKET = 5'd11,
              S_WAIT_PAYMENT = 5'd12,
              S_PAYMENT_APPROVED = 5'd13,
              S_OPEN_EXIT_GATE = 5'd14,
              S_WAIT_EXIT_PASS = 5'd15,
              S_CLOSE_EXIT_GATE = 5'd16,
              S_UPDATE_COUNT_OUT = 5'd17,
              S_MARK_TICKET_USED = 5'd18,
              S_FULL = 5'd19,
              S_ALARM = 5'd20;


    // State register block
    always @(posedge CLK or posedge RESET) begin
        if (RESET) begin
            state <= S_IDLE;
        end
        else begin
            state <= next_state;
        end
    end

    // Next-state combinational logic
    // - Entry has priority over exit in S_IDLE
    // - No simultaneous entry/exit handling
    always @(*) begin
    next_state = state;  // default: stay in current state
    // FSM states
    case (state)

        S_IDLE: begin
            if (entry_sensor) begin
              next_state = S_ENTRY_DETECT; // if entry_sensor is active, go to entry detect
            end
            else if (exit_sensor) begin
              next_state = S_EXIT_DETECT; // if exit_sensor is active, go to exit detect
            end
            else begin
              next_state = S_IDLE; // else stay in IDLE
            end
        end

        S_ENTRY_DETECT: begin
            next_state = S_CHECK_SPACE; // separate detect state for clearer FSM flow and easier explanation
        end

        S_CHECK_SPACE: begin
            if (garage_full_internal) begin
              next_state = S_FULL; // if garage is full, go to full state
            end
            else begin
              next_state = S_ISSUE_TICKET; // else go to issue-ticket state
            end
        end

        S_ISSUE_TICKET: begin
            next_state = S_OPEN_ENTRY_GATE; // after issuing ticket, proceed to open entry gate
        end

        S_OPEN_ENTRY_GATE: begin
            next_state = S_WAIT_ENTRY_PASS; // open gate, then wait for car to pass
        end

        S_WAIT_ENTRY_PASS: begin
            if (entry_passed) begin
              next_state = S_CLOSE_ENTRY_GATE; // if car passed entry gate, go to close entry gate
            end
            else begin
              next_state = S_WAIT_ENTRY_PASS;  // else stay here
            end
        end

        S_CLOSE_ENTRY_GATE: begin
            next_state = S_UPDATE_COUNT_IN; // close entry gate after car enters
        end

        S_UPDATE_COUNT_IN: begin
            next_state = S_IDLE; // increment occupancy after successful entry
        end

        S_EXIT_DETECT: begin
            next_state = S_WAIT_TICKET_SCAN;
        end

        S_WAIT_TICKET_SCAN: begin
            if (scan_ticket) begin
              next_state = S_VALIDATE_TICKET; // if scan_ticket is active, go to validate-ticket
            end
            else begin
              next_state = S_WAIT_TICKET_SCAN;   // else stay here
            end
        end

        S_VALIDATE_TICKET: begin
            if (ticket_valid) begin
              next_state = S_WAIT_PAYMENT;  // if ticket_valid, go to wait-payment
            end
            else begin
              next_state = S_INVALID_TICKET; // else go to invalid-ticket
            end
        end

        S_INVALID_TICKET: begin
            next_state = S_ALARM; // activate alarm when in 'invalid ticket'
        end

        S_WAIT_PAYMENT: begin
            if (payment_done) begin
              next_state = S_PAYMENT_APPROVED;  // if payment_done, go to payment-approved
            end
            else begin
              next_state = S_WAIT_PAYMENT; // wait here unitl payment recieved
            end
        end

        S_PAYMENT_APPROVED: begin
            next_state = S_OPEN_EXIT_GATE;
            // move to open exit gate
        end

        S_OPEN_EXIT_GATE: begin
            next_state = S_WAIT_EXIT_PASS;
            // move to wait-exit-pass
        end

        S_WAIT_EXIT_PASS: begin
            if (exit_passed) begin
              next_state = S_CLOSE_EXIT_GATE; // if car passed exit gate, go to close exit gate
            end
            else begin
              next_state = S_WAIT_EXIT_PASS; // stay in state until exit is passed
            end
        end

        S_CLOSE_EXIT_GATE: begin
            next_state = S_UPDATE_COUNT_OUT; // move to update-count-out
        end

        S_UPDATE_COUNT_OUT: begin
            next_state = S_MARK_TICKET_USED; // move to mark-ticket-used
        end

        S_MARK_TICKET_USED: begin
            next_state = S_IDLE; // move back to idle
        end

        S_FULL: begin
            next_state = S_IDLE; // move back to idle
        end

        S_ALARM: begin
            next_state = S_IDLE; // move back to idle
        end

        default: begin
            next_state = S_IDLE;  // safety fallback
        end
    endcase
end

// Output combinational logic (Moore style)
// - Default all outputs to 0 first
always @(*) begin
    // default all outputs to 0
    issue_ticket_cmd = 1'b0;
    mark_ticket_used_cmd = 1'b0;
    inc_count = 1'b0;
    dec_count = 1'b0;
    entry_gate_open_cmd = 1'b0;
    entry_gate_close_cmd = 1'b0;
    exit_gate_open_cmd = 1'b0;
    exit_gate_close_cmd = 1'b0;
    garage_full = 1'b0;
    invalid_ticket = 1'b0;
    alarm = 1'b0;

    case (state)
        S_IDLE: begin
        end

        S_ENTRY_DETECT: begin
        end

        S_CHECK_SPACE: begin
        end

        S_ISSUE_TICKET: begin
            issue_ticket_cmd = 1'b1;  // issue new ticket
        end

        S_OPEN_ENTRY_GATE: begin
            entry_gate_open_cmd = 1'b1;   // open entry gate
        end

        S_WAIT_ENTRY_PASS: begin
        end

        S_CLOSE_ENTRY_GATE: begin
            entry_gate_close_cmd = 1'b1;  // close entry gate
        end

        S_UPDATE_COUNT_IN: begin
            inc_count = 1'b1;       // increment occupancy
        end

        S_EXIT_DETECT: begin
        end

        S_WAIT_TICKET_SCAN: begin
        end

        S_VALIDATE_TICKET: begin
        end

        S_INVALID_TICKET: begin
            invalid_ticket = 1'b1;   // flag invalid ticket
        end

        S_WAIT_PAYMENT: begin
        end

        S_PAYMENT_APPROVED: begin
        end

        S_OPEN_EXIT_GATE: begin
            exit_gate_open_cmd = 1'b1; // open exit gate
        end

        S_WAIT_EXIT_PASS: begin
        end

        S_CLOSE_EXIT_GATE: begin
            exit_gate_close_cmd = 1'b1; // close exit gate
        end

        S_UPDATE_COUNT_OUT: begin
            dec_count = 1'b1;  // decrement occupancy
        end

        S_MARK_TICKET_USED: begin
            mark_ticket_used_cmd = 1'b1;  // mark scanned ticket used
        end

        S_FULL: begin
            garage_full = 1'b1;       // indicate garage full
        end

        S_ALARM: begin
            alarm = 1'b1;  // indicate alarm/error
        end

        default: begin // already set default values before case statement, no need to here for default
        end
    endcase
end
endmodule
// 4) TOP Module
// Purpose:
// - Connect all modules together
// - Combine RESET and admin_override into one reset signal
// - Pass internal control/status signals between submodules

module parking_garage_top #(
    parameter CAPACITY  = 7'd100,
    parameter TICKET_WL = 8,
    parameter COUNT_WL  = 7
)(
    input CLK,
    input RESET,
    input admin_override,

    // External sensors / controls
    input entry_sensor,
    input entry_passed,
    input exit_sensor,
    input exit_passed,
    input scan_ticket,
    input [TICKET_WL-1:0] ticket_in,
    input payment_done,

    // External outputs
    output entry_gate_open_cmd,
    output entry_gate_close_cmd,
    output exit_gate_open_cmd,
    output exit_gate_close_cmd,
    output [TICKET_WL-1:0] ticket_out,
    output garage_full,
    output invalid_ticket,
    output alarm,
    output [COUNT_WL-1:0] occupancy_count,
    output [COUNT_WL-1:0] spaces_remaining
);

    // Internal wires

    // Combined reset
    wire reset_all;

    // FSM - ticket manager
    wire issue_ticket_cmd;
    wire mark_ticket_used_cmd;

    // ticket manager - FSM
    wire ticket_valid;

    // FSM - occupancy counter
    wire inc_count;
    wire dec_count;

    // occupancy counter - FSM
    wire garage_full_internal;

    // RESET Logic : admin_override behaves like reset

    assign reset_all = RESET | admin_override;

    // Instantiate occupancy_counter
    occupancy_counter #(
        .CAPACITY(CAPACITY),
        .COUNT_WL(COUNT_WL)
    ) U_OCCUPANCY_COUNTER (
        .CLK(CLK),
        .RESET(reset_all),
        .inc_count(inc_count),
        .dec_count(dec_count),
        .occupancy_count(occupancy_count),
        .spaces_remaining(spaces_remaining),
        .garage_full_internal(garage_full_internal)
    );

    // Instantiate ticket_manager
    ticket_manager #(
        .TICKET_WL(TICKET_WL)
    ) U_TICKET_MANAGER (
        .CLK(CLK),
        .RESET(reset_all),
        .issue_ticket_cmd(issue_ticket_cmd),
        .mark_ticket_used_cmd(mark_ticket_used_cmd),
        .ticket_in(ticket_in),
        .ticket_out(ticket_out),
        .ticket_valid(ticket_valid)
    );

    // Instantiate parking_controller_fsm
    parking_controller_fsm #(
        .COUNT_WL(COUNT_WL)
    ) U_PARKING_CONTROLLER_FSM (
        .CLK(CLK),
        .RESET(reset_all),

        .entry_sensor(entry_sensor),
        .entry_passed(entry_passed),
        .exit_sensor(exit_sensor),
        .exit_passed(exit_passed),
        .scan_ticket(scan_ticket),
        .payment_done(payment_done),
        .ticket_valid(ticket_valid),
        .garage_full_internal(garage_full_internal),

        .issue_ticket_cmd(issue_ticket_cmd),
        .mark_ticket_used_cmd(mark_ticket_used_cmd),
        .inc_count(inc_count),
        .dec_count(dec_count),

        .entry_gate_open_cmd(entry_gate_open_cmd),
        .entry_gate_close_cmd(entry_gate_close_cmd),
        .exit_gate_open_cmd(exit_gate_open_cmd),
        .exit_gate_close_cmd(exit_gate_close_cmd),

        .garage_full(garage_full),
        .invalid_ticket(invalid_ticket),
        .alarm(alarm)
    );

endmodule