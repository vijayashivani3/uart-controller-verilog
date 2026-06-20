# UART Controller (Verilog)

Parameterized UART transmitter/receiver with TX/RX FIFOs, 
verified via self-checking testbench.

## Architecture
- baud_gen.v — 16x oversampling clock divider, parameterized via custom synthesizable clog2 function
- uart_tx.v — 5-state FSM (IDLE→START→DATA→[PARITY]→STOP), configurable parity, LSB-first
- uart_rx.v — 16x oversampling FSM, false-start rejection, mid-bit sampling
- fifo.v — 4-word synchronous FIFO, MSB-wraparound full/empty detection
- uart_top.v — full integration, TX/RX FIFO handshaking

## Verification
Self-checking testbench, multi-byte loopback test (0x11, 0x22, 0x33).
All 4 integration tests pass: byte values, ordering, no parity/frame errors.

## Bugs found and fixed (debug log)
1. TX FIFO double-pop race — added tx_wait_busy lock so the next pop
   can't happen until tx_busy confirms the prior tx_start was accepted.
2. Testbench read-back race — first rx_rd_en assertion coincided with
   the clock edge that woke the testbench, causing a double pop and
   silently dropping byte 0. Fixed with a #1 delay before the read loop.
3. uart_rx start-bit timing — original design transitioned to DATA at
   tick 7 instead of waiting the full 16-tick period, causing every
   bit to be sampled one tick early (1-bit right shift).
4. $clog2 synthesis incompatibility — Vivado 2017.4's synth engine
   rejected $clog2() when used to size a register width, despite it
   working fine in simulation. Replaced with an equivalent
   synthesizable Verilog function.

## Synthesis Results (Artix-7, xc7a35tcpg236-1)
| Resource         | Used | Available | Utilization |
|------------------|------|-----------|--------------|
| Slice LUTs       | 92   | 20,800    | 0.44%        |
| Slice Registers  | 89   | 41,600    | 0.21%        |
| Block RAM        | 0    | 50        | 0%           |
| DSP              | 0    | 90        | 0%           |

## Simulation
Vivado/xsim, CLK_FREQ=16000, BAUD_RATE=100, PARITY_MODE=0, timescale 1ns/1ps
