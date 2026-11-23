# UART Transmitter and Receiver (SystemVerilog)

An 8N1 UART (8 data bits, no parity, 1 stop bit) written in SystemVerilog, with a self-checking loopback testbench.

**Status:** Simulation: not yet run. Vivado synthesis: not yet run. FPGA board testing: not yet done.

## What is UART?
UART sends bytes between two devices over one wire, one bit at a time, with no shared clock. Both sides agree on a speed (the baud rate) beforehand. The line idles high. A frame is a start bit (0), 8 data bits (least significant bit first), then a stop bit (1).

## Files
| Path | Description |
|---|---|
| `rtl/uart_tx.sv` | Transmitter FSM |
| `rtl/uart_rx.sv` | Receiver FSM |
| `tb/tb_uart_loopback.sv` | Self-checking testbench (TX wired to RX) |

## Parameter
`CLKS_PER_BIT = clock frequency / baud rate`. For a 100 MHz clock at 9600 baud this is 100,000,000 / 9600 = 10417. The testbench uses 8 so the simulation runs quickly.

## Transmitter FSM
| State | Action | Next state |
|---|---|---|
| IDLE | Line high, wait for `tx_start` | START when `tx_start` = 1 |
| START | Drive 0 for one bit time | DATA |
| DATA | Send bits 0 to 7, one bit time each | STOP after bit 7 |
| STOP | Drive 1 for one bit time | IDLE |

## Receiver FSM
| State | Action | Next state |
|---|---|---|
| IDLE | Wait for the line to go low | START |
| START | Wait half a bit, check the line is still low | DATA, or IDLE if it was a glitch |
| DATA | Wait one bit time, sample, store bits 0 to 7 | STOP after bit 7 |
| STOP | Wait one bit time, check the line is high | IDLE, pulse `rx_valid` (or `frame_err`) |

The receiver samples in the middle of each bit so small timing differences do not matter. The `rx` input passes through two flip-flops first, because it arrives asynchronously.

## How to run
**Vivado:** create a project, add the files in `rtl/` as design sources and `tb/` as simulation sources, set `tb_uart_loopback` as the top module, and run behavioural simulation.

**Icarus Verilog and GTKWave (free):**
```
iverilog -g2012 -o sim.out rtl/uart_tx.sv rtl/uart_rx.sv tb/tb_uart_loopback.sv
vvp sim.out
gtkwave uart_loopback.vcd
```

## Testbench
The testbench connects TX to RX and sends corner cases (0x00, 0xFF, 0x55, 0xAA, 0x41, 0x01, 0x80) plus 30 random bytes. For each byte it checks that the received value matches and that no framing error or timeout occurred, and prints PASS or FAIL. A correct run ends with `ALL TESTS PASSED (37 checks)`.

## Limitations
- 8N1 only: no parity, no FIFO, no configurable frame format
- Baud rate is set by a parameter, not at run time
- Not tested on hardware

## Next steps
- Add a waveform screenshot and simulation log
- Add a Vivado synthesis report and schematic
- Add a top module and XDC file for the Spartan-7 Boolean board, then test on hardware
