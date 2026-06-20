// ============================================================
// Module      : uart_rx
// Description : UART Receiver FSM with 16x oversampling
//               States: IDLE -> START -> DATA(8) -> [PARITY] -> STOP
//               PARITY_MODE: 0=none, 1=even, 2=odd
// Inputs      : clk, rst, tick, rx (serial input line)
// Outputs     : rx_data[7:0], rx_done, parity_error, frame_error
// ============================================================

module uart_rx #(
    parameter PARITY_MODE = 0   // 0=none, 1=even, 2=odd
)(
    input  wire       clk,
    input  wire       rst,
    input  wire       tick,          // 16x baud tick from baud_gen
    input  wire       rx,            // Serial input line
    output reg  [7:0] rx_data,        // Received byte
    output reg        rx_done,        // Pulses high for 1 cycle when byte ready
    output reg        parity_error,   // 1 if parity check failed
    output reg        frame_error     // 1 if stop bit was not 1
);

    // ---- FSM States ----
    localparam IDLE   = 3'b000;
    localparam START  = 3'b001;
    localparam DATA   = 3'b010;
    localparam PARITY = 3'b011;
    localparam STOP   = 3'b100;

    reg [2:0] state;
    reg [3:0] tick_count;   // Counts 0-15 ticks = 1 bit period
    reg [2:0] bit_index;    // Which data bit (0-7) we're receiving
    reg [7:0] data_reg;     // Shift register for incoming bits
    reg       received_parity; // Parity bit as received

    always @(posedge clk) begin
        if (rst) begin
            state           <= IDLE;
            rx_data         <= 0;
            rx_done         <= 1'b0;
            parity_error    <= 1'b0;
            frame_error     <= 1'b0;
            tick_count      <= 0;
            bit_index       <= 0;
            data_reg        <= 0;
            received_parity <= 0;
        end
        else begin
            rx_done <= 1'b0;  // Default: clear done pulse each cycle

            case (state)

                IDLE: begin
                    if (rx == 1'b0) begin
                        // Possible start bit detected
                        tick_count <= 0;
                        state      <= START;
                    end
                end

                START: begin
                    if (tick) begin
                        if (tick_count == 7) begin
                            // Middle of start bit - verify it's still 0
                            if (rx == 1'b0) begin
                                tick_count <= 0;
                                bit_index  <= 0;
                                state      <= DATA;
                            end
                            else begin
                                // False start (noise) - go back to IDLE
                                state <= IDLE;
                            end
                        end
                        else
                            tick_count <= tick_count + 1;
                    end
                end

                DATA: begin
                    if (tick) begin
                        if (tick_count == 15) begin
                            // Full bit period elapsed - we already sampled
                            tick_count <= 0;
                            if (bit_index == 7) begin
                                if (PARITY_MODE != 0)
                                    state <= PARITY;
                                else
                                    state <= STOP;
                            end
                            else
                                bit_index <= bit_index + 1;
                        end
                        else begin
                            tick_count <= tick_count + 1;
                            // Sample at the middle of the bit period (tick_count == 7)
                            if (tick_count == 7) begin
                                data_reg[bit_index] <= rx;
                            end
                        end
                    end
                end

                PARITY: begin
                    if (tick) begin
                        if (tick_count == 7) begin
                            received_parity <= rx; // sample parity bit
                        end
                        if (tick_count == 15) begin
                            tick_count <= 0;
                            state      <= STOP;
                        end
                        else
                            tick_count <= tick_count + 1;
                    end
                end

                STOP: begin
                    if (tick) begin
                        if (tick_count == 7) begin
                            // Middle of stop bit - check it's 1
                            if (rx == 1'b1)
                                frame_error <= 1'b0;
                            else
                                frame_error <= 1'b1;

                            // Check parity if enabled
                            if (PARITY_MODE == 1)
                                parity_error <= (received_parity != (^data_reg)); // even
                            else if (PARITY_MODE == 2)
                                parity_error <= (received_parity != ~(^data_reg)); // odd
                            else
                                parity_error <= 1'b0;

                            // Output the received byte
                            rx_data <= data_reg;
                            rx_done <= 1'b1;
                        end
                        if (tick_count == 15) begin
                            tick_count <= 0;
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