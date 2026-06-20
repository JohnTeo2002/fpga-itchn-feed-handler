# Ultra-Low Latency FPGA Market Data Feed Handler

A line-rate, hardware-native **NASDAQ ITCH 5.0 Market Data Decoder** and **Pre-Trade Risk Management Engine** implemented in SystemVerilog. By processing raw Ethernet frames on the fly, this system bypasses the kernel network stack to achieve deterministic sub-microsecond latency.

## 🚀 Key Architectural Features
- **Line-Rate Processing:** Directly handles streams from a 10GbE MAC/PCS interface on a fixed clock of 156.25 MHz.
- **Deterministic 2-Cycle Risk Filter:** Implements max order quantity checks, price sanity bounds, and cross-account wash trading rules within **12.8 ns**.
- **Robust Clock Domain Crossing (CDC):** Employs asymmetric, shallow Asynchronous FIFOs to hand off metadata securely to the 250 MHz PCIe system domain.
- **Modern Verification Pipeline:** Co-designed with a `cocotb` framework using Python for behavioral testing.

## Design Trade-offs & Implementation Notes
- To achieve a strict 2-clock-cycle latency in the Risk Engine, Wash-Trading Prevention is constrained to a highly optimized 16-entry parallel CAM register array tracking the most recent active internal orders.
- The Stream Parser incorporates an aggressive multi-byte barrel shifter to dynamically realign unaligned MoldUDP64 packet payloads to byte-0 boundaries before extracting ITCH fields.

## 🛠️ Simulation & Verification
Ensure you have `cocotb` and `icarus-verilog` installed, then run the simulation from the `tb/` folder:
```bash
cd tb
make SIM=icarus