`timescale 1ns / 1ns

module tb_parking_garage;

    parameter CAPACITY  = 7'd100;
    parameter TICKET_WL = 8;
    parameter COUNT_WL  = 7;
    parameter ClockPeriod = 10;

    reg CLK;
    reg RESET;
    reg admin_override;
    reg entry_sensor;
    reg entry_passed;
    reg exit_sensor;
    reg exit_passed;
    reg scan_ticket;
    reg [TICKET_WL-1:0] ticket_in;
    reg payment_done;

    wire entry_gate_open_cmd;
    wire entry_gate_close_cmd;
    wire exit_gate_open_cmd;
    wire exit_gate_close_cmd;
    wire [TICKET_WL-1:0] ticket_out;
    wire garage_full;
    wire invalid_ticket;
    wire alarm;
    wire [COUNT_WL-1:0] occupancy_count;
    wire [COUNT_WL-1:0] spaces_remaining;

    reg [TICKET_WL-1:0] saved_ticket;
    integer i;

    parking_garage_top #(
        .CAPACITY(CAPACITY),
        .TICKET_WL(TICKET_WL),
        .COUNT_WL(COUNT_WL)
    ) UUT (
        .CLK(CLK),
        .RESET(RESET),
        .admin_override(admin_override),
        .entry_sensor(entry_sensor),
        .entry_passed(entry_passed),
        .exit_sensor(exit_sensor),
        .exit_passed(exit_passed),
        .scan_ticket(scan_ticket),
        .ticket_in(ticket_in),
        .payment_done(payment_done),
        .entry_gate_open_cmd(entry_gate_open_cmd),
        .entry_gate_close_cmd(entry_gate_close_cmd),
        .exit_gate_open_cmd(exit_gate_open_cmd),
        .exit_gate_close_cmd(exit_gate_close_cmd),
        .ticket_out(ticket_out),
        .garage_full(garage_full),
        .invalid_ticket(invalid_ticket),
        .alarm(alarm),
        .occupancy_count(occupancy_count),
        .spaces_remaining(spaces_remaining)
    );

    initial CLK = 1'b0;
    always #(ClockPeriod / 2) CLK = ~CLK;   // free-running clock

    initial begin
        $dumpfile("waveforms/parking_garage.vcd"); // GTKwave verification
        $dumpvars(0, tb_parking_garage);

        $monitor("t=%0t reset=%b ovrd=%b entry=%b exit=%b scan=%b pay=%b tin=%h tout=%h occ=%d rem=%d full=%b inv=%b alarm=%b",
                 $time, RESET, admin_override, entry_sensor, exit_sensor, scan_ticket,
                 payment_done, ticket_in, ticket_out, occupancy_count, spaces_remaining,
                 garage_full, invalid_ticket, alarm);
    end

    initial begin
        RESET = 1'b0;
        admin_override = 1'b0;
        entry_sensor = 1'b0;
        entry_passed = 1'b0;
        exit_sensor = 1'b0;
        exit_passed = 1'b0;
        scan_ticket = 1'b0;
        ticket_in = {TICKET_WL{1'b0}};
        payment_done = 1'b0;
        saved_ticket = {TICKET_WL{1'b0}};

        RESET = 1'b1;   // apply reset
        @(posedge CLK);
        RESET = 1'b0;
        @(posedge CLK);   // allow reset to settle

        entry_sensor = 1'b1;   // request entry
        @(posedge CLK);
        entry_sensor = 1'b0;

        repeat (4) @(posedge CLK);   // 4 clocks: ENTRY_DETECT -> CHECK_SPACE -> ISSUE_TICKET -> OPEN_ENTRY_GATE

        saved_ticket = ticket_out;   // store issued ticket

        entry_passed = 1'b1;   // car passes entry gate
        @(posedge CLK);
        entry_passed = 1'b0;

        repeat (3) @(posedge CLK);   // 3 clocks: CLOSE_ENTRY_GATE -> UPDATE_COUNT_IN -> IDLE

        exit_sensor = 1'b1;   // request exit
        @(posedge CLK);
        exit_sensor = 1'b0;

        repeat (2) @(posedge CLK);   // 2 clocks: EXIT_DETECT -> WAIT_TICKET_SCAN

        ticket_in = saved_ticket;   // use valid ticket
        scan_ticket = 1'b1;
        @(posedge CLK);
        scan_ticket = 1'b0;

        repeat (1) @(posedge CLK);   // 1 clock: WAIT_TICKET_SCAN -> VALIDATE_TICKET

        payment_done = 1'b1;   // payment complete
        @(posedge CLK);
        payment_done = 1'b0;

        repeat (2) @(posedge CLK);   // 2 clocks: WAIT_PAYMENT -> PAYMENT_APPROVED -> OPEN_EXIT_GATE

        exit_passed = 1'b1;   // car exits
        @(posedge CLK);
        exit_passed = 1'b0;

        repeat (3) @(posedge CLK);   // 3 clocks: CLOSE_EXIT_GATE -> UPDATE_COUNT_OUT -> MARK_TICKET_USED

        exit_sensor = 1'b1;   // invalid ticket test
        @(posedge CLK);
        exit_sensor = 1'b0;

        repeat (2) @(posedge CLK);   // 2 clocks: EXIT_DETECT -> WAIT_TICKET_SCAN

        ticket_in = 8'hAA;   // never-issued ticket
        scan_ticket = 1'b1;
        @(posedge CLK);
        scan_ticket = 1'b0;

        repeat (3) @(posedge CLK);   // 3 clocks: VALIDATE_TICKET -> INVALID_TICKET -> ALARM

        exit_sensor = 1'b1;   // reused ticket test
        @(posedge CLK);
        exit_sensor = 1'b0;

        repeat (2) @(posedge CLK);   // 2 clocks: EXIT_DETECT -> WAIT_TICKET_SCAN

        ticket_in = saved_ticket;   // already-used ticket
        scan_ticket = 1'b1;
        @(posedge CLK);
        scan_ticket = 1'b0;

        repeat (3) @(posedge CLK);   // 3 clocks: VALIDATE_TICKET -> INVALID_TICKET -> ALARM

        admin_override = 1'b1;   // reset through override
        @(posedge CLK);
        admin_override = 1'b0;

        repeat (2) @(posedge CLK);   // 2 clocks: reset recovery and return to clean IDLE

        $finish;
    end

endmodule