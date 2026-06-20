// ============================================================
// Module      : uart_top
// Description : Top-level UART controller
//               Integrates baud_gen + uart_tx + uart_rx + 2x fifo
//               Clean external interface: write bytes to send,
//               read bytes that have arrived
// Parameters  : CLK_FREQ, BAUD_RATE, PARITY_MODE
// Inputs      : clk, rst, rx (serial in),
//               tx_wr_en, tx_wr_data[7:0]  (processor -> TX FIFO)
//               rx_rd_en                   (processor reads RX FIFO)
// Outputs     : tx (serial out),
//               tx_fifo_full               (processor checks before writing)
//               rx_rd_data[7:0], rx_fifo_empty (processor checks before reading)
//               parity_error, frame_error
// ============================================================

module uart_top #(
    parameter CLK_FREQ    = 100_000_000,
    parameter BAUD_RATE   = 9600,
    parameter PARITY_MODE = 0
)(
    input  wire       clk,
    input  wire       rst,

    // Serial pins
    input  wire       rx,
    output wire        tx,

    // TX FIFO write interface (processor -> UART)
    input  wire       tx_wr_en,
    input  wire [7:0] tx_wr_data,
    output wire       tx_fifo_full,

    // RX FIFO read interface (UART -> processor)
    input  wire       rx_rd_en,
    output wire [7:0] rx_rd_data,
    output wire       rx_fifo_empty,

    // Error flags (direct from uart_rx)
    output wire       parity_error,
    output wire       frame_error
);

    // ============================================================
    // INTERNAL WIRES
    // ============================================================

    wire       tick;            // 16x baud tick

    // TX FIFO <-> uart_tx wires
    wire [7:0] tx_fifo_dout;
    wire       tx_fifo_empty;
    reg        tx_fifo_rd_en;

    // uart_tx control
    reg        tx_start;
    wire       tx_busy, tx_done;

    // uart_rx -> RX FIFO wires
    wire [7:0] rx_data_internal;
    wire       rx_done;

    // ============================================================
    // MODULE INSTANTIATIONS
    // ============================================================

    // 1. Baud rate generator
    baud_gen #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) bg (
        .clk(clk),
        .rst(rst),
        .tick(tick)
    );

    // 2. TX FIFO - processor writes here, uart_tx reads from here
    fifo tx_fifo (
        .clk(clk),
        .rst(rst),
        .wr_en(tx_wr_en),
        .rd_en(tx_fifo_rd_en),
        .din(tx_wr_data),
        .dout(tx_fifo_dout),
        .full(tx_fifo_full),
        .empty(tx_fifo_empty)
    );

    // 3. UART Transmitter
    uart_tx #(
        .PARITY_MODE(PARITY_MODE)
    ) utx (
        .clk(clk),
        .rst(rst),
        .tick(tick),
        .tx_start(tx_start),
        .tx_data(tx_fifo_dout),
        .tx(tx),
        .tx_busy(tx_busy),
        .tx_done(tx_done)
    );

    // 4. UART Receiver
    uart_rx #(
        .PARITY_MODE(PARITY_MODE)
    ) urx (
        .clk(clk),
        .rst(rst),
        .tick(tick),
        .rx(rx),
        .rx_data(rx_data_internal),
        .rx_done(rx_done),
        .parity_error(parity_error),
        .frame_error(frame_error)
    );

    // 5. RX FIFO - uart_rx writes here, processor reads from here
    fifo rx_fifo (
        .clk(clk),
        .rst(rst),
        .wr_en(rx_done),           // Write every time a byte is received
        .rd_en(rx_rd_en),
        .din(rx_data_internal),
        .dout(rx_rd_data),
        .full(),                   // Not used - if processor reads regularly, won't overflow
        .empty(rx_fifo_empty)
    );

    // ============================================================
    // TX CONTROL LOGIC
    // Pop a byte from tx_fifo and start uart_tx whenever:
    //   - uart_tx is not currently busy
    //   - tx_fifo has data waiting
    // ============================================================
     reg tx_pending;     // 1 cycle delay to let fifo_rd_en register the pop
        reg tx_wait_busy;   // wait until tx_busy actually rises before allowing next pop
    
        always @(posedge clk) begin
            if (rst) begin
                tx_fifo_rd_en <= 1'b0;
                tx_start      <= 1'b0;
                tx_pending    <= 1'b0;
                tx_wait_busy  <= 1'b0;
            end
            else begin
                tx_fifo_rd_en <= 1'b0;  // Default: don't read unless conditions met
                tx_start      <= 1'b0;  // Default: don't start unless conditions met
    
                if (!tx_busy && !tx_fifo_empty && !tx_pending && !tx_wait_busy) begin
                    // Pop a byte from FIFO this cycle
                    tx_fifo_rd_en <= 1'b1;
                    tx_pending    <= 1'b1;
                end
                else if (tx_pending) begin
                    // FIFO output (tx_fifo_dout) is now valid - start transmission
                    tx_start     <= 1'b1;
                    tx_pending   <= 1'b0;
                    tx_wait_busy <= 1'b1;   // Now wait for tx_busy to rise, confirming start was accepted
                end
                else if (tx_wait_busy && tx_busy) begin
                    // uart_tx has confirmed it's now transmitting - safe to allow next pop later
                    tx_wait_busy <= 1'b0;
                end
            end
        end
  
endmodule