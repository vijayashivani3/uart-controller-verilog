// ============================================================
// Module      : fifo
// Description : 4-word deep synchronous FIFO, 8-bit wide
//               Used to buffer UART TX/RX data
// Inputs      : clk, rst, wr_en, rd_en, din[7:0]
// Outputs     : dout[7:0], full, empty
// ============================================================

module fifo (
    input  wire       clk,
    input  wire       rst,
    input  wire       wr_en,
    input  wire       rd_en,
    input  wire [7:0] din,
    output reg  [7:0] dout,
    output wire       full,
    output wire       empty
);

    // 4 locations, each 8 bits
    reg [7:0] mem [0:3];

    // 2-bit pointers (wrap around 0-3), plus 1 extra bit for full/empty detection
    reg [2:0] wr_ptr;  // write pointer (3 bits: bit2 = wrap flag)
    reg [2:0] rd_ptr;  // read pointer

    always @(posedge clk) begin
        if (rst) begin
            wr_ptr <= 0;
            rd_ptr <= 0;
            dout   <= 0;
        end
        else begin
            // Write operation
            if (wr_en && !full) begin
                mem[wr_ptr[1:0]] <= din;
                wr_ptr <= wr_ptr + 1;
            end

            // Read operation
            if (rd_en && !empty) begin
                dout   <= mem[rd_ptr[1:0]];
                rd_ptr <= rd_ptr + 1;
            end
        end
    end

    // FIFO is empty when read and write pointers are exactly equal
    assign empty = (wr_ptr == rd_ptr);

    // FIFO is full when pointers differ only in the wrap bit (bit 2)
    // i.e., same lower 2 bits, but different bit 2 -> 4 writes ahead of reads
    assign full = (wr_ptr[1:0] == rd_ptr[1:0]) && (wr_ptr[2] != rd_ptr[2]);

endmodule