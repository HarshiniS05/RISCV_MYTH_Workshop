#  RISC-V based MYTH Workshop

## Microprocessor for You in Thirty Hours (MYTH)

This repository documents my learning journey and hands-on implementation of a **RISC-V based CPU** using **TL-Verilog** and **Makerchip** as part of the **RISC-V based MYTH (Microprocessor for You in Thirty Hours)** workshop conducted by VSD and Redwood EDA.


---

## Table of Contents

- [Day 1 — Introduction to RISC-V ISA and GNU Compiler Toolchain](#day-1)
- [Day 2 — Application Binary Interface and Verification Flow](#day-2)
- [Day 3 — Digital Logic with TL-Verilog in Makerchip IDE](#day-3)
- [Day 4 — Building a RISC-V CPU Core (Single Cycle)](#day-4)
- [Day 5 — Pipelining and Completing the RISC-V CPU](#day-5)
- [Final CPU Output](#final-cpu-output)

---

## Day 1
### Introduction to RISC-V ISA and GNU Compiler Toolchain

**Topics Covered:**
- C program to hardware execution flow
- Role of compiler, assembler, and ISA
- Hardware Description Language and RTL
- Integer number representation (signed and unsigned)
- Two's complement and 64-bit number ranges
- GNU toolchain and RISC-V compilation

**Key Concepts:**

| Concept | Summary |
|---------|---------|
| ISA | Interface between software and hardware |
| Compiler | Converts C to ISA-specific assembly |
| Assembler | Converts assembly to binary machine code |
| HDL | Describes hardware; synthesised into logic gates |
| Two's complement | Standard method to represent signed integers |
| 64-bit signed range | −2^63 to +2^63 − 1 |
| 64-bit unsigned range | 0 to 2^64 − 1 |
| `spike` | RISC-V instruction-set simulator |
| `pk` | Proxy kernel for spike |

**Software to Hardware Flow:**
C Program → (Compiler) → Assembly → (Assembler) → Binary → Hardware

---

## Day 2
### Application Binary Interface and Basic Verification Flow

**Topics Covered:**
- What is the ABI and where it fits in the software stack
- RISC-V registers — naming, width, and ABI roles
- Memory addressing — little-endian byte ordering
- Load and store instructions
- Instruction encoding formats (I-type, R-type, S-type)
- Lab: C program calling assembly function
- Lab: Running on PicoRV32 RTL simulation

**RISC-V Register Summary:**

| Register | ABI Name | Usage |
|----------|----------|-------|
| x0 | zero | Hard-wired zero |
| x1 | ra | Return address |
| x2 | sp | Stack pointer |
| x10–x11 | a0–a1 | Function args / return values |
| x12–x17 | a2–a7 | Function arguments |
| x5–x7 | t0–t2 | Temporaries |
| x8–x9 | s0–s1 | Saved registers |

**Instruction Formats:**

| Format | Used For |
|--------|---------|
| I-type | Loads, ADDI, JALR |
| R-type | ADD, SUB, AND, OR, XOR |
| S-type | Stores (SW, SD) |
| B-type | Branches |
| U-type | LUI, AUIPC |
| J-type | JAL |

---

## Day 3
### Digital Logic with TL-Verilog in Makerchip IDE

**Topics Covered:**
- Logic gates and boolean operators
- Combinational circuits
- Sequential logic and flip-flops
- Pipelining and timing abstraction
- Validity concepts and clock gating
- Hierarchical hardware design

**Labs Completed:**

| Lab | Description |
|-----|-------------|
| Combinational Logic | Inverter, AND, OR gates |
| Vectors | 4-bit arithmetic operations |
| Multiplexer | 2:1 and vector MUX |
| Combinational Calculator | +, -, *, / with op select |
| Fibonacci Generator | Sequential logic with `>>` operator |
| Sequential Calculator | Feedback from previous output |
| Pipeline Error Detection | Multi-stage error propagation |
| Counter + Calculator in Pipeline | Combined sequential datapath |
| 2-Cycle Calculator | Retimed pipeline with valid signal |
| Calculator with Memory | Store and recall operations |

**TL-Verilog Key Operators:**

| Operator | Meaning |
|----------|---------|
| `>>1$signal` | Signal value from 1 cycle ago |
| `>>2$signal` | Signal value from 2 cycles ago |
| `?$condition` | When block — X when condition false |
| `==?` | Don't-care comparison |
| `@N` | Pipeline stage N |

---

## Day 4
### Building a RISC-V CPU Core (Single Cycle)

**Topics Covered:**
- PC logic and instruction fetch
- Instruction type decode (R, I, S, B, U, J)
- Immediate value construction with sign extension
- Register file read with when conditions
- ALU — ADD and ADDI
- Register file write
- Branch condition evaluation
- Branch target PC and PC MUX

**7-Step Build Order:**
Step 1 → PC Logic         "Where is the next instruction?"
Step 2 → Fetch            "Read it from instruction memory"
Step 3 → Decode           "What type? What fields?"
Step 4 → RF Read          "Get source register values"
Step 5 → ALU              "Compute the result"
Step 6 → RF Write         "Write result to destination"
Step 7 → Branches         "Redirect PC if branch taken"

**Test Program (Sum 1 to 9):**
```asm
ADD   r10, r0,  r0      // x10 = 0  (initialize sum)
ADD   r14, r10, r0      // x14 = 0  (initialize accumulator)
ADDI  r12, r10, 1010    // x12 = 10 (loop limit)
ADD   r13, r10, r0      // x13 = 0  (initialize counter)
ADD   r14, r13, r14     // x14 = x14 + i
ADDI  r13, r13, 1       // x13++
BLT   r13, r12, -8      // if i < 10, loop
ADD   r10, r14, r0      // x10 = result
```
**Expected Result:** `x10 = 45`

---

## Day 5
### Pipelining and Completing the RISC-V CPU

**Topics Covered:**
- 3-stage to 5-stage pipeline
- Waterfall diagrams and hazard handling
- Register file bypass (data forwarding)
- Complete RV32I instruction decode
- Complete ALU (all RV32I operations)
- Load/Store with Data Memory
- Jump instructions (JAL / JALR)
- Simulation verification

**Pipeline Stage Overview:**

| Stage | Label | Operations |
|-------|-------|------------|
| @0 | PC | Reset, valid, PC MUX, IMem read enable |
| @1 | Fetch/Decode | Instruction fetch, type decode, immediate, fields |
| @2 | RF Read + ALU | Register read, bypass, ALU, branch compare |
| @3 | RF Write | Write-back, validity gating, DMem signals |
| @4 | DMem Access | Data memory read/write |
| @5 | Load Write-back | Load data capture and RF write |

**Hazard Handling Summary:**

| Hazard | Root Cause | Solution |
|--------|-----------|----------|
| RAW register | RF read before write | Bypass `>>1$result` / `>>2$result` |
| Control — branch | 2 wrong instructions fetched | Invalidate 2 shadow cycles |
| Control — load | Data unavailable 2 cycles | Invalidate 2 shadow cycles; re-fetch |
| Control — jump | 2 wrong instructions fetched | Invalidate 2 shadow cycles |

**Labs Completed:**

| Slide | Lab |
|-------|-----|
| 33 | 3-Cycle Valid Signal |
| 37 | 3-Cycle Pipelined RISC-V |
| 39 | Register File Bypass |
| 42 | Branches ~1 IPC |
| 44 | Complete Instruction Decode |
| 45 | Complete ALU |
| 48 | Load Redirect |
| 49 | Load Data RF Write MUX |
| 51 | DMem Connect |
| 52 | Load/Store in Test Program |
| 53 | Jump Instructions (JAL/JALR) |

**Final Program with Load/Store:**
```asm
ADD   r10, r0,  r0
ADD   r14, r10, r0
ADDI  r12, r10, 1010
ADD   r13, r10, r0
ADD   r14, r13, r14
ADDI  r13, r13, 1
BLT   r13, r12, 1111111111000
ADD   r10, r14, r0
SW    r0,  r10, 10000      // store sum to address 16
LW    r17, r0,  10000      // load back into x17
```

**Final Passing Condition:**
```tlv
*passed = |cpu/xreg[17]>>5$value == (1+2+3+4+5+6+7+8+9);
```
**Expected:** `xreg[17] = 45 = 0x2D`

**Final TLV Code:** [day5/tlv_code/final.tlv](day5/tlv_code/final.tlv)

---

## Final CPU Output

The complete pipelined RISC-V CPU successfully simulates the sum 1–9 program,
stores the result to data memory, and loads it back into register x17.
Simulation passes with `xreg[17] = 45`.

![Final RISC-V CPU Output](screenshots/day5/risc.png)

---

## Repository Structure
RISCV_MYTH_Workshop/
├── day1_intro.md
├── day2_riscv_basics.md
├── day3_tlv.md
├── day4_riscv_cpu.md
├── day5_pipeline.md
├── day5/
│   └── tlv_code/
│       └── final.tlv
└── screenshots/
├── day2/
├── day3/
├── day4/
└── day5/

---

## Tools Used

| Tool | Purpose |
|------|---------|
| Makerchip IDE | TL-Verilog simulation and visualization |
| TL-Verilog | Hardware description language |
| RISC-V GNU Toolchain | C to RISC-V compilation |
| Spike simulator | RISC-V ISA simulation |
| PicoRV32 | RTL verification |

---

## References

- Workshop repo: https://github.com/stevehoover/RISC-V_MYTH_Workshop
- Makerchip IDE: https://makerchip.com
- TL-Verilog spec: https://www.redwoodeda.com/tl-verilog
- RISC-V ISA spec: https://riscv.org/technical/specifications/
- VSD MYTH Workshop: https://www.vlsisystemdesign.com
