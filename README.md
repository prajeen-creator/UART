# UART Controller — Verilog Implementation

A fully functional **UART (Universal Asynchronous Receiver/Transmitter)** controller implemented in Verilog, designed as a placement preparation project for VLSI roles.

---

## 📌 Features

- **8N1 UART frame format** — 1 start bit, 8 data bits, 1 stop bit, no parity
- **Parameterized** — easily change clock frequency and baud rate
- **FSM-based design** — clean, readable, interview-ready state machine
- **Mid-bit sampling** — receiver samples at the center of each bit for maximum noise margin
- **Metastability handling** — 2-flip-flop synchronizer on the RX input
- **Framing error detection** — flags invalid stop bits
- **Loopback testbench** — 5 test cases with automated pass/fail checking

---

## 🗂️ Project Structure

```
uart_controller/
├── rtl/
│   ├── uart_tx.v      # UART Transmitter
│   ├── uart_rx.v      # UART Receiver
│   └── uart_top.v     # Top-level wrapper
├── tb/
│   └── tb_uart.v      # Testbench (loopback, 5 test cases)
└── docs/
    └── architecture.md
```

---

## ⚙️ Parameters

| Parameter  | Default     | Description                        |
|------------|-------------|------------------------------------|
| `CLK_FREQ` | 50,000,000  | System clock frequency (Hz)        |
| `BAUD_RATE`| 9600        | UART baud rate (bits per second)   |

To change to 115200 baud on a 100 MHz clock:
```verilog
uart_top #(
    .CLK_FREQ  (100_000_000),
    .BAUD_RATE (115200)
) u_uart ( ... );
```

---

## 🔄 UART Frame Format (8N1)

```
     ___                                             ___
    |   | START | D0 | D1 | D2 | D3 | D4 | D5 | D6 | D7 | STOP |
____|   |_______|____|____|____|____|____|____|____|____|________|
    ↑                                                            ↑
  IDLE                                                         IDLE
  (HIGH)                                                       (HIGH)
```

---

## 🧠 Design Details

### Transmitter FSM

```
IDLE → START → DATA (8 bits, LSB first) → STOP → DONE → IDLE
```

- **IDLE**: Waits for `tx_start` pulse; latches `tx_data`
- **START**: Drives `tx=0` for one bit period (`CLK_FREQ/BAUD_RATE` cycles)
- **DATA**: Shifts out bits 0–7, one per bit period
- **STOP**: Drives `tx=1` for one bit period
- **DONE**: Pulses `tx_done=1` for one cycle

### Receiver FSM

```
IDLE → START (half-bit wait + glitch check) → DATA → STOP → DONE → IDLE
```

- **Mid-bit sampling**: After detecting the start-bit falling edge, waits **half a bit-period** before first sample — this centres all subsequent samples
- **Glitch rejection**: Re-checks the start bit after the half-period wait
- **2-FF synchronizer**: `rx` passes through two flip-flops before use to prevent metastability

---

## 🧪 Running the Simulation

### Option A: EDA Playground (Recommended — no install needed)

1. Go to [https://www.edaplayground.com](https://www.edaplayground.com)
2. Create a new playground
3. Add design files:
   - Paste `uart_tx.v` content → New tab
   - Paste `uart_rx.v` content → New tab  
   - Paste `uart_top.v` content → New tab
4. Paste `tb_uart.v` as the testbench
5. Select **Icarus Verilog 0.9.7** as the simulator
6. Check **"Open EPWave after run"**
7. Click **Run**

### Option B: Icarus Verilog (Local)

```bash
# Compile
iverilog -o uart_sim rtl/uart_tx.v rtl/uart_rx.v rtl/uart_top.v tb/tb_uart.v

# Simulate
vvp uart_sim

# View waveforms
gtkwave uart_wave.vcd
```

### Expected Output

```
=========================================
  UART Loopback Testbench Starting
  CLK=50000000 Hz  BAUD=9600
=========================================
[TC1] TX done. Sent: 0x55
[TC1] PASS: Sent=0x55  Received=0x55
[TC2] TX done. Sent: 0xa5
[TC2] PASS: Sent=0xa5  Received=0xa5
[TC3] TX done. Sent: 0x0
[TC3] PASS: Sent=0x0  Received=0x0
[TC4] TX done. Sent: 0xff
[TC4] PASS: Sent=0xff  Received=0xff
[TC5] TX done. Sent: 0x4d
[TC5] PASS: Sent=0x4d  Received=0x4d
=========================================
  Results: 5 PASSED / 0 FAILED
=========================================
  ALL TESTS PASSED!
```

---

## 📖 Signals Reference

### uart_tx

| Signal     | Dir | Width | Description                          |
|------------|-----|-------|--------------------------------------|
| `clk`      | in  | 1     | System clock                         |
| `rst_n`    | in  | 1     | Active-low async reset               |
| `tx_start` | in  | 1     | Pulse HIGH to start transmission     |
| `tx_data`  | in  | 8     | Parallel data byte to transmit       |
| `tx`       | out | 1     | Serial output (idle=HIGH)            |
| `tx_busy`  | out | 1     | HIGH during transmission             |
| `tx_done`  | out | 1     | 1-cycle pulse on completion          |

### uart_rx

| Signal     | Dir | Width | Description                          |
|------------|-----|-------|--------------------------------------|
| `clk`      | in  | 1     | System clock                         |
| `rst_n`    | in  | 1     | Active-low async reset               |
| `rx`       | in  | 1     | Serial input (idle=HIGH)             |
| `rx_data`  | out | 8     | Received parallel data byte          |
| `rx_done`  | out | 1     | 1-cycle pulse when byte received     |
| `rx_error` | out | 1     | HIGH on framing error                |

---

## 💡 What This Project Demonstrates

| Concept | Where used |
|---|---|
| FSM design | Both TX and RX state machines |
| Timing & baud rate | `CLKS_PER_BIT` parameter derivation |
| Clock domain crossing | 2-FF synchronizer in RX |
| Metastability | Synchronizer explanation in comments |
| Protocol understanding | 8N1 frame, start/stop bits |
| Testbench writing | Self-checking TB with pass/fail |
| Code parameterization | `CLK_FREQ`, `BAUD_RATE` generics |

---

## 🔮 Future Enhancements (mention these in interviews!)

- Add **parity bit** support (even/odd)
- Add **FIFO buffers** for TX and RX
- Implement **flow control** (CTS/RTS)
- Port to **SystemVerilog** with a UVM testbench
- Synthesize on FPGA (Xilinx Basys3) and test with a real serial terminal

---

*Built as a VLSI placement project. Tools: Icarus Verilog, GTKWave / EDA Playground.*
