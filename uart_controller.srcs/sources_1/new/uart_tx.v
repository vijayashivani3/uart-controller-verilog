// ============================================================
// Module      : uart_tx
// Description : UART Transmitter FSM
//               States: IDLE -> START -> DATA(8) -> [PARITY] -> STOP
//               PARITY_MODE: 0=none, 1=even, 2=odd
// Inputs      : clk, rst, tick, tx_start, tx_data[7:0]
// Outputs     : tx (serial output line), tx_busy, tx_done
// ============================================================

module uart_tx #(
    parameter PARITY_MODE = 0   // 0=none, 1=even, 2=odd
)(
    input  wire       clk,
    input  wire       rst,
    input  wire       tick,      // 16x baud tick from baud_gen
    input  wire       tx_start,  // Pulse high to begin transmission
    input  wire [7:0] tx_data,   // Byte to transmit
    output reg        tx,        // Serial output line
    output reg        tx_busy,   // 1 while transmitting
    output reg        tx_done    // Pulses high for 1 cycle when frame complete
);

    // ---- FSM States ----
    localparam IDLE   = 3'b000;
    localparam START  = 3'b001;
    localparam DATA   = 3'b010;
    localparam PARITY = 3'b011;
    localparam STOP   = 3'b100;

    reg [2:0] state;
    reg [3:0] tick_count;   // Counts 0-15 ticks = 1 bit period
    reg [2:0] bit_index;    // Which data bit (0-7) we're sending
    reg [7:0] data_reg;     // Latched copy of tx_data
    reg       parity_bit;   // Computed parity

    always @(posedge clk) begin
        if (rst) begin
            state      <= IDLE;
            tx         <= 1'b1;  // Idle line is high
            tx_busy    <= 1'b0;
            tx_done    <= 1'b0;
            tick_count <= 0;
            bit_index  <= 0;
            data_reg   <= 0;
            parity_bit <= 0;
        end
        else begin
            tx_done <= 1'b0;  // Default: clear done pulse each cycle

            case (state)

                IDLE: begin
                    tx      <= 1'b1;
                    tx_busy <= 1'b0;
                    if (tx_start) begin
                        data_reg   <= tx_data;
                        tx_busy    <= 1'b1;
                        tick_count <= 0;
                        // Compute parity now (XOR of all 8 data bits)
                        parity_bit <= ^tx_data; // even parity by default
                        state      <= START;
                    end
                end

                START: begin
                    tx <= 1'b0;  // Start bit = 0
                    if (tick) begin
                        if (tick_count == 15) begin
                            tick_count <= 0;
                            bit_index  <= 0;
                            state      <= DATA;
                        end
                        else
                            tick_count <= tick_count + 1;
                    end
                end

                DATA: begin
                    tx <= data_reg[bit_index]; // Send LSB first
                    if (tick) begin
                        if (tick_count == 15) begin
                            tick_count <= 0;
                            if (bit_index == 7) begin
                                // All 8 bits sent
                                if (PARITY_MODE != 0)
                                    state <= PARITY;
                                else
                                    state <= STOP;
                            end
                            else
                                bit_index <= bit_index + 1;
                        end
                        else
                            tick_count <= tick_count + 1;
                    end
                end

                PARITY: begin
                    // Even parity: send XOR of data bits
                    // Odd parity: send inverted XOR
                    if (PARITY_MODE == 1)
                        tx <= parity_bit;        // even parity
                    else
                        tx <= ~parity_bit;       // odd parity
                    if (tick) begin
                        if (tick_count == 15) begin
                            tick_count <= 0;
                            state      <= STOP;
                        end
                        else
                            tick_count <= tick_count + 1;
                    end
                end

                STOP: begin
                    tx <= 1'b1;  // Stop bit = 1
                    if (tick) begin
                        if (tick_count == 15) begin
                            tick_count <= 0;
                            tx_busy    <= 1'b0;
                            tx_done    <= 1'b1;  // Pulse done for 1 cycle
                            state      <= IDLE;
                        end
                        else
                            tick_count <= tick_count + 1;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule