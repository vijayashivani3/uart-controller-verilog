// ============================================================
// Module      : baud_gen
// Description : Baud rate generator - produces a tick pulse
//               at 16x the baud rate for UART oversampling
// Parameters  : CLK_FREQ  - system clock frequency in Hz
//               BAUD_RATE - desired baud rate
// Inputs      : clk, rst
// Outputs     : tick - single-cycle pulse at 16x baud rate
// ============================================================
module baud_gen #(
    parameter CLK_FREQ  = 100_000_000,
    parameter BAUD_RATE = 9600
)(
    input  wire clk,
    input  wire rst,
    output reg  tick
);
    // Divider value: how many clock cycles per tick
    // tick rate = baud_rate * 16
    localparam DIVIDER = CLK_FREQ / (BAUD_RATE * 16);

    // Manual ceiling-log2 function, used instead of the $clog2 system
    // function. Vivado 2017.4's synthesis engine rejects $clog2 when
    // it's used to size a localparam that then sizes a reg declaration
    // ([Synth 8-2722] system function call clog2 is not allowed here),
    // even though it works fine in simulation. This function computes
    // the identical result but as ordinary synthesizable Verilog, so
    // there's no system-function call for synth to reject.
    function integer clog2;
        input integer value;
        integer i;
        begin
            clog2 = 0;
            for (i = value - 1; i > 0; i = i >> 1)
                clog2 = clog2 + 1;
        end
    endfunction

    // Counter width - enough bits to count up to DIVIDER
    localparam COUNTER_WIDTH = clog2(DIVIDER);
    reg [COUNTER_WIDTH-1:0] counter;

    always @(posedge clk) begin
        if (rst) begin
            counter <= 0;
            tick    <= 1'b0;
        end
        else if (counter == DIVIDER - 1) begin
            counter <= 0;
            tick    <= 1'b1;  // Pulse high for one clock cycle
        end
        else begin
            counter <= counter + 1;
            tick    <= 1'b0;
        end
    end
endmodule