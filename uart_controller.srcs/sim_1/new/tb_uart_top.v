// ============================================================
// Module      : tb_uart_top
// Description : Full integration test - write 3 bytes to TX FIFO,
//               loopback tx->rx, read 3 bytes from RX FIFO,
//               verify order and values match
// ============================================================

`timescale 1ns / 1ps

module tb_uart_top;

    reg clk, rst;
    initial clk = 0;
    always #5 clk = ~clk;  // 100MHz clock

    reg        tx_wr_en;
    reg  [7:0] tx_wr_data;
    wire       tx_fifo_full;

    reg        rx_rd_en;
    wire [7:0] rx_rd_data;
    wire       rx_fifo_empty;

    wire       parity_error, frame_error;
    wire       tx_line;

    uart_top #(
        .CLK_FREQ(16000),
        .BAUD_RATE(100),
        .PARITY_MODE(0)
    ) DUT (
        .clk(clk),
        .rst(rst),
        .rx(tx_line),         // LOOPBACK: tx feeds directly into rx
        .tx(tx_line),
        .tx_wr_en(tx_wr_en),
        .tx_wr_data(tx_wr_data),
        .tx_fifo_full(tx_fifo_full),
        .rx_rd_en(rx_rd_en),
        .rx_rd_data(rx_rd_data),
        .rx_fifo_empty(rx_fifo_empty),
        .parity_error(parity_error),
        .frame_error(frame_error)
    );

    integer pass_count, fail_count;
    reg [7:0] expected [0:2];
    integer i;

    initial begin
        pass_count = 0;
        fail_count = 0;

        expected[0] = 8'h11;
        expected[1] = 8'h22;
        expected[2] = 8'h33;

        $display("===== UART TOP INTEGRATION TEST =====");
        $display("Writing 3 bytes to TX FIFO: 0x11, 0x22, 0x33");
        $display(" ");

        rst = 1; tx_wr_en = 0; tx_wr_data = 0; rx_rd_en = 0;
        repeat(2) @(posedge clk);
        rst = 0;
        @(posedge clk);

        // Write 3 bytes into TX FIFO back-to-back
        tx_wr_en   = 1;
        tx_wr_data = 8'h11;
        @(posedge clk);
        tx_wr_data = 8'h22;
        @(posedge clk);
        tx_wr_data = 8'h33;
        @(posedge clk);
        tx_wr_en = 0;

        $display("All 3 bytes written. Waiting for transmission + reception...");

        // Each byte takes ~16000ns to fully transmit (10 bit periods x 1600ns)
        // 3 bytes = ~48000ns, plus FIFO/control overhead. Wait 60000ns to be safe.
        repeat(6000) @(posedge clk);

        $display(" ");
        $display("Reading back from RX FIFO...");
        $display(" ");

        // FIX: add #1 delay so the first rx_rd_en assertion lands 1ns after the
        // clock edge that woke us from repeat(6000), rather than coinciding with it.
        // Without this, rx_rd_en=1 and the FIFO's own posedge clk process fire in
        // the same timestep - the scheduler pops the FIFO twice before the loop
        // reads back the result, silently discarding byte 0 (0x11) and shifting
        // everything up by one position. Every subsequent iteration was already safe
        // because each is preceded by @(posedge clk); #1 from the previous iteration.
        #1;

        // Read 3 bytes from RX FIFO and check against expected[]
        for (i = 0; i < 3; i = i + 1) begin
            if (!rx_fifo_empty) begin
                rx_rd_en = 1;
                @(posedge clk); #1;
                rx_rd_en = 0;
                @(posedge clk); #1;

                if (rx_rd_data == expected[i]) begin
                    $display("Byte %0d: PASS | received=0x%02h expected=0x%02h",
                              i, rx_rd_data, expected[i]);
                    pass_count = pass_count + 1;
                end
                else begin
                    $display("Byte %0d: FAIL | received=0x%02h expected=0x%02h",
                              i, rx_rd_data, expected[i]);
                    fail_count = fail_count + 1;
                end
            end
            else begin
                $display("Byte %0d: FAIL | RX FIFO empty - byte never arrived", i);
                fail_count = fail_count + 1;
            end
        end

        // Check no errors occurred
        if (!parity_error && !frame_error) begin
            $display("Error Flags Test: PASS | no parity or frame errors");
            pass_count = pass_count + 1;
        end
        else begin
            $display("Error Flags Test: FAIL | parity_error=%b frame_error=%b",
                      parity_error, frame_error);
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