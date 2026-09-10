`timescale 1ns/1ps

module tb_uart;

    // --------------------------------------------------------
    // Parameters
    // --------------------------------------------------------
    localparam CLK_FREQ   = 50_000_000;
    localparam BAUD_RATE  = 9600;
    localparam CLK_PERIOD = 20; // 20ns = 50 MHz

    // --------------------------------------------------------
    // DUT signals
    // --------------------------------------------------------
    reg        clk;
    reg        rst_n;
    reg        tx_start;
    reg  [7:0] tx_data;
    wire       tx_line;
    wire       tx_busy;
    wire       tx_done;
    wire [7:0] rx_data;
    wire       rx_done;
    wire       rx_error;

    // --------------------------------------------------------
    // rx_done flag — set by always block, cleared by task
    // Avoids missing the rx_done pulse (race condition fix)
    // --------------------------------------------------------
    reg rx_done_flag;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rx_done_flag <= 1'b0;
        else if (rx_done)
            rx_done_flag <= 1'b1;
    end

    // --------------------------------------------------------
    // Instantiate DUT (loopback: rx = tx)
    // --------------------------------------------------------
    uart_top #(
        .CLK_FREQ  (CLK_FREQ),
        .BAUD_RATE (BAUD_RATE)
    ) dut (
        .clk      (clk),
        .rst_n    (rst_n),
        .tx_start (tx_start),
        .tx_data  (tx_data),
        .tx       (tx_line),
        .tx_busy  (tx_busy),
        .tx_done  (tx_done),
        .rx       (tx_line),  // LOOPBACK
        .rx_data  (rx_data),
        .rx_done  (rx_done),
        .rx_error (rx_error)
    );

    // --------------------------------------------------------
    // Clock generation: 50 MHz
    // --------------------------------------------------------
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // --------------------------------------------------------
    // Waveform dump
    // --------------------------------------------------------
    initial begin
        $dumpfile("uart_wave.vcd");
        $dumpvars(0, tb_uart);
    end

    // --------------------------------------------------------
    // Task: send one byte and wait for reception
    // FIX: use rx_done_flag (level) instead of @posedge rx_done (edge)
    //      because RX finishes ~2600 cycles BEFORE tx_done fires
    // --------------------------------------------------------
    integer pass_count;
    integer fail_count;

    task send_and_check;
        input [7:0] data;
        input [31:0] test_num;
        begin
            // Clear the flag before starting
            rx_done_flag = 1'b0;

            // Pulse tx_start
            @(posedge clk);
            tx_data  = data;
            tx_start = 1'b1;
            @(posedge clk);
            tx_start = 1'b0;

            // Wait for RX to complete using flag (level-sensitive — never misses)
            wait(rx_done_flag == 1'b1);
            @(posedge clk); // one extra cycle for rx_data to be stable

            // Wait for TX to also finish cleanly
            wait(tx_busy == 1'b0);

            // Check received data
            if (rx_data === data && rx_error === 1'b0) begin
                $display("[TC%0d] PASS  |  Sent: 0x%0h (%08b)  |  Received: 0x%0h (%08b)",
                          test_num, data, data, rx_data, rx_data);
                pass_count = pass_count + 1;
            end else begin
                $display("[TC%0d] FAIL  |  Sent: 0x%0h  |  Received: 0x%0h  |  Error=%b",
                          test_num, data, rx_data, rx_error);
                fail_count = fail_count + 1;
            end

            // Inter-frame gap
            repeat(50) @(posedge clk);
        end
    endtask

    // --------------------------------------------------------
    // Main test sequence
    // --------------------------------------------------------
    initial begin
        pass_count = 0;
        fail_count = 0;

        // Reset
        rst_n    = 1'b0;
        tx_start = 1'b0;
        tx_data  = 8'h00;
        repeat(10) @(posedge clk);
        rst_n = 1'b1;
        repeat(5) @(posedge clk);

        $display("================================================");
        $display("   UART Loopback Testbench  |  9600 baud");
        $display("================================================");

        send_and_check(8'h55, 1);  // 01010101 - alternating bits
        send_and_check(8'hA5, 2);  // 10100101 - mixed pattern
        send_and_check(8'h00, 3);  // 00000000 - all zeros
        send_and_check(8'hFF, 4);  // 11111111 - all ones
        send_and_check(8'h4D, 5);  // ASCII 'M'

        $display("------------------------------------------------");
        $display("   Results: %0d PASSED  /  %0d FAILED", pass_count, fail_count);
        $display("------------------------------------------------");
        if (fail_count == 0)
            $display("   ALL TESTS PASSED!");
        else
            $display("   SOME TESTS FAILED - check waveforms.");

        $finish;
    end

    // --------------------------------------------------------
    // Timeout watchdog
    // --------------------------------------------------------
    initial begin
        #200_000_000;
        $display("TIMEOUT: Simulation exceeded 200ms limit.");
        $finish;
    end

endmodule
