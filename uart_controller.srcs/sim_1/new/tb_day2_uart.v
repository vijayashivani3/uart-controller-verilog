// ============================================================
// Module      : tb_day2_uart
// Description : Loopback test (TX -> RX) + FIFO test
// ============================================================

`timescale 1ns / 1ps

module tb_day2_uart;

    reg clk, rst;
    initial clk = 0;
    always #5 clk = ~clk;  // 100MHz clock

    // ---- Baud generator (small divider for fast sim) ----
    wire tick;
    baud_gen #(
        .CLK_FREQ(16000),
        .BAUD_RATE(100)
    ) bg (
        .clk(clk),
        .rst(rst),
        .tick(tick)
    );

    // ---- UART TX ----
    reg        tx_start;
    reg  [7:0] tx_data;
    wire       tx, tx_busy, tx_done;

    uart_tx #(.PARITY_MODE(0)) utx (
        .clk(clk), .rst(rst), .tick(tick),
        .tx_start(tx_start), .tx_data(tx_data),
        .tx(tx), .tx_busy(tx_busy), .tx_done(tx_done)
    );

    // ---- UART RX (loopback: rx = tx) ----
    wire [7:0] rx_data;
    wire       rx_done, parity_error, frame_error;

    uart_rx #(.PARITY_MODE(0)) urx (
        .clk(clk), .rst(rst), .tick(tick),
        .rx(tx),  // LOOPBACK: TX output feeds directly into RX input
        .rx_data(rx_data), .rx_done(rx_done),
        .parity_error(parity_error), .frame_error(frame_error)
    );

    // ---- FIFO ----
    reg        fifo_wr, fifo_rd;
    reg  [7:0] fifo_din;
    wire [7:0] fifo_dout;
    wire       fifo_full, fifo_empty;

    fifo ff (
        .clk(clk), .rst(rst),
        .wr_en(fifo_wr), .rd_en(fifo_rd),
        .din(fifo_din), .dout(fifo_dout),
        .full(fifo_full), .empty(fifo_empty)
    );

    integer pass_count, fail_count;
    reg [7:0] captured_rx_data;
    reg       got_rx_done;

    initial begin
        pass_count = 0;
        fail_count = 0;

        $display("===== UART LOOPBACK TEST (TX -> RX) =====");
        rst = 1; tx_start = 0; tx_data = 0;
        fifo_wr = 0; fifo_rd = 0; fifo_din = 0;
        repeat(2) @(posedge clk);
        rst = 0;

        // Send byte 0xA5 = 10100101
        @(posedge clk);
        tx_data  = 8'hA5;
        tx_start = 1;
        @(posedge clk);
        tx_start = 0;

        // Wait for rx_done to actually pulse (poll every cycle)
        captured_rx_data = 8'h00;
        got_rx_done = 0;
        repeat(1800) begin
            @(posedge clk);
            if (rx_done) begin
                captured_rx_data = rx_data;
                got_rx_done = 1;
            end
        end

        if (got_rx_done) begin
            if (captured_rx_data == 8'hA5) begin
                $display("Loopback Test: PASS | sent=0xA5 received=0x%02h", captured_rx_data);
                pass_count = pass_count + 1;
            end
            else begin
                $display("Loopback Test: FAIL | sent=0xA5 received=0x%02h", captured_rx_data);
                fail_count = fail_count + 1;
            end
        end
        else begin
            $display("Loopback Test: FAIL | rx_done never asserted, rx_data=0x%02h", rx_data);
            fail_count = fail_count + 1;
        end

        if (frame_error)
            $display("Frame Error Test: FAIL | frame_error=1 (unexpected)");
        else begin
            $display("Frame Error Test: PASS | frame_error=0");
            pass_count = pass_count + 1;
        end

        $display(" ");
        $display("===== FIFO TEST =====");

        // Test 1: FIFO starts empty
        if (fifo_empty) begin
            $display("FIFO Test 1: PASS | FIFO empty at start");
            pass_count = pass_count + 1;
        end else begin
            $display("FIFO Test 1: FAIL | FIFO should be empty at start");
            fail_count = fail_count + 1;
        end

        // Test 2: Write 4 values, check full
        fifo_wr = 1;
        fifo_din = 8'h11; @(posedge clk);
        fifo_din = 8'h22; @(posedge clk);
        fifo_din = 8'h33; @(posedge clk);
        fifo_din = 8'h44; @(posedge clk);
        fifo_wr = 0;
        @(posedge clk); #1;

        if (fifo_full) begin
            $display("FIFO Test 2: PASS | FIFO full after 4 writes");
            pass_count = pass_count + 1;
        end else begin
            $display("FIFO Test 2: FAIL | FIFO should be full after 4 writes");
            fail_count = fail_count + 1;
        end

        // Test 3: Read back values, check order (FIFO = first in first out)
        fifo_rd = 1;
        @(posedge clk); #1;
        if (fifo_dout == 8'h11) begin
            $display("FIFO Test 3: PASS | first read = 0x%02h (expected 0x11)", fifo_dout);
            pass_count = pass_count + 1;
        end else begin
            $display("FIFO Test 3: FAIL | first read = 0x%02h (expected 0x11)", fifo_dout);
            fail_count = fail_count + 1;
        end

        @(posedge clk); #1;
        if (fifo_dout == 8'h22) begin
            $display("FIFO Test 4: PASS | second read = 0x%02h (expected 0x22)", fifo_dout);
            pass_count = pass_count + 1;
        end else begin
            $display("FIFO Test 4: FAIL | second read = 0x%02h (expected 0x22)", fifo_dout);
            fail_count = fail_count + 1;
        end

        @(posedge clk); #1;
        @(posedge clk); #1;
        fifo_rd = 0;
        @(posedge clk); #1;

        // Test 5: FIFO empty again after reading all 4
        if (fifo_empty) begin
            $display("FIFO Test 5: PASS | FIFO empty after reading all 4");
            pass_count = pass_count + 1;
        end else begin
            $display("FIFO Test 5: FAIL | FIFO should be empty after reading all 4");
            fail_count = fail_count + 1;
        end

        $display(" ");
        $display("==============================================");
        if (fail_count == 0)
            $display("  ALL %0d TESTS PASSED", pass_count);
        else
            $display("  %0d PASSED, %0d FAILED", pass_count, fail_count);
        $display("==============================================");

        $finish;
    end

endmodule