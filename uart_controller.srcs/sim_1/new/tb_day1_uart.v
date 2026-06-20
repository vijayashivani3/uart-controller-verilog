// ============================================================
// Module      : tb_day1_uart
// Description : Testbench for baud_gen and uart_tx
//               Uses a small divider value for fast simulation
// ============================================================

`timescale 1ns / 1ps

module tb_day1_uart;

    reg clk, rst;
    initial clk = 0;
    always #5 clk = ~clk;  // 100MHz clock

    // ---- Baud generator (small divider for fast sim) ----
    // Using CLK_FREQ=1600, BAUD_RATE=100 -> DIVIDER = 1600/(100*16) = 1
    // That's too fast. Use CLK_FREQ=16000, BAUD_RATE=100 -> DIVIDER=10
    wire tick;
    baud_gen #(
        .CLK_FREQ(16000),
        .BAUD_RATE(100)
    ) bg (
        .clk(clk),
        .rst(rst),
        .tick(tick)
    );

    // ---- UART TX (no parity) ----
    reg        tx_start;
    reg  [7:0] tx_data;
    wire       tx, tx_busy, tx_done;

    uart_tx #(
        .PARITY_MODE(0)
    ) utx (
        .clk(clk),
        .rst(rst),
        .tick(tick),
        .tx_start(tx_start),
        .tx_data(tx_data),
        .tx(tx),
        .tx_busy(tx_busy),
        .tx_done(tx_done)
    );

    // ---- Tick counter check ----
    integer tick_count_check;

    initial begin
        $display("===== BAUD GEN TEST =====");
        rst = 1; tx_start = 0; tx_data = 0;
        tick_count_check = 0;
        repeat(2) @(posedge clk);
        rst = 0;

        // Count ticks over 100 clock cycles
        repeat(100) begin
            @(posedge clk);
            if (tick) tick_count_check = tick_count_check + 1;
        end
        $display("Ticks in 100 clock cycles: %0d (expected ~10 for DIVIDER=10)",
                  tick_count_check);
        if (tick_count_check >= 9 && tick_count_check <= 11)
            $display("Baud Gen Test: PASS");
        else
            $display("Baud Gen Test: FAIL");

        $display(" ");
        $display("===== UART TX TEST =====");
        $display("Transmitting byte 8'b10110010 (0xB2)...");

        // Send byte 0xB2 = 10110010
        @(posedge clk);
        tx_data  = 8'b10110010;
        tx_start = 1;
        @(posedge clk);
        tx_start = 0;

        // Monitor tx line - print every time it changes
        // Run long enough for full frame: START + 8 DATA + STOP = 10 bit periods
        // Each bit period = 10 ticks = ~100 clock cycles. 10 bits = ~1000 cycles
        repeat(1700) @(posedge clk);

        if (tx_done)
            $display("UART TX Test: tx_done pulsed - frame complete");

        $display(" ");
        $display("===== DAY 1 UART TESTS COMPLETE =====");
        $finish;
    end

    // Monitor tx line transitions
    reg prev_tx;
    initial prev_tx = 1;
    always @(posedge clk) begin
        if (tx !== prev_tx) begin
            $display("Time=%0t : tx changed to %b", $time, tx);
            prev_tx <= tx;
        end
    end

endmodule