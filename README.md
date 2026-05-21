#  RISC-V based MYTH Workshop

## Microprocessor for You in Thirty Hours (MYTH)

This repository documents my learning journey and hands-on implementation of a **RISC-V based CPU** using **TL-Verilog** and **Makerchip** as part of the **RISC-V based MYTH (Microprocessor for You in Thirty Hours)** workshop conducted by VSD and Redwood EDA.


---

#  Workshop Overview

The workshop provides a structured introduction to:
- RISC-V ISA fundamentals
- GNU toolchain and Spike simulation
- ABI and verification flow
- Combinational and sequential logic
- TL-Verilog design methodology
- Single-cycle and pipelined RISC-V CPU design
- Branch handling and memory operations
- Load/store implementation
- CPU verification and debugging

Participants progressively build a functional RISC-V CPU while understanding both software and hardware aspects of processor design.

---

# 🛠 Tools Used

- Makerchip IDE
- TL-Verilog
- GNU Toolchain (GCC, GDB, Binutils)
- Spike RISC-V Simulator
- Verilator
- GTKWave
- RISC-V GCC Toolchain

---

# Topics Covered

## DAY 1 – Introduction to RISC-V ISA
- RISC-V basics
- GNU compiler toolchain
- Integer number representation
- Signed and unsigned arithmetic
- Basic assembly programming

## DAY 2 – ABI & Verification
- Application Binary Interface (ABI)
- Function calls
- Stack operations
- Basic verification flow
- Icarus Verilog basics

## DAY 3 – TL-Verilog & Makerchip
- Combinational logic
- Sequential logic
- Pipelined logic
- Validity
- Hierarchy

## DAY 4 – Basic RISC-V CPU
- Fetch logic
- Decode logic
- Execute stage
- Register file
- ALU implementation
- Branch instructions

## DAY 5 – Pipelined RISC-V CPU
- CPU pipelining
- Hazard handling
- Register bypass
- Load/store instructions
- Jump instructions
- Memory operations

---

# 📂 Repository Structure

```text
RISCV_MYTH_Workshop/
│
├── README.md
├── day1_intro.md
├── day2_riscv_basics.md
├── day3_tlv.md
├── day4_riscv_cpu.md
├── day5_pipeline.md
│
└── screenshots/
    ├── day1/
    ├── day2/
    ├── day3/
    ├── day4/
    └── day5/
```

---

#  Labs & Experiments

✔ RISC-V Assembly Programming 
✔ Instruction Decode Logic 
✔ Register File Design 
✔ ALU Implementation 
✔ Branch Handling 
✔ Pipeline Validity 
✔ Register Bypass 
✔ Load & Store Operations 
✔ Jump Instructions 
✔ Pipelined CPU Design 

---

#  Featured Implementations

- Combinational Logic Circuits
- Sequential Counter
- Calculator using TL-Verilog
- Register File
- ALU
- Branch Logic
- Load/Store Unit
- Pipelined RV32I CPU

---

# Simulation & Verification

This repository includes:
- Makerchip simulation screenshots
- Waveforms
- CPU pipeline implementation
- TL-Verilog code snippets
- Detailed explanations for every experiment

---

# Learning Outcomes

Through this workshop I gained understanding in:
- RISC-V ISA
- CPU microarchitecture
- Pipeline implementation
- Digital logic design
- Hardware verification
- TL-Verilog methodology
- Processor debugging and optimization

---


# 📖 References

- Makerchip IDE
- Redwood EDA
- RISC-V Foundation
- VLSI System Design (VSD)

---

# Author

Harshini S

---

#  Acknowledgement

Special thanks to:
- Steve Hoover
- Redwood EDA
- VLSI System Design (VSD)

for providing the MYTH workshop and open-source learning ecosystem for RISC-V and TL-Verilog.

---


