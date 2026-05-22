# Day 1 – Introduction to RISC-V ISA and GNU Compiler Toolchain

## Overview

Day 1 introduces the fundamental concept of how a high-level program written
in C eventually gets executed on physical hardware. The key bridge between
software and hardware is the **Instruction Set Architecture (ISA)** — the
language that the hardware understands.

---

## Topics Covered

- C program to hardware execution flow
- Role of the compiler, assembler, and ISA
- Hardware Description Language (HDL) and RTL
- Integer number representation (unsigned and signed)
- Two's complement and 64-bit number ranges
- GNU toolchain and RISC-V compilation

---

## Section 1: How Software Talks to Hardware

### Concept

Every program you write in a high-level language like C goes through several
transformation steps before it can run on physical hardware:

```
C Program
   ↓  (Compiler)
Assembly Language Program
   ↓  (Assembler)
Machine Language (Binary: 0s and 1s)
   ↓  (Execution)
Hardware (CPU / Chip)
   ↓
Output
```

Each step converts the program into a lower-level representation that is
closer to what the hardware physically understands.

### Role of ISA

The **Instruction Set Architecture (ISA)** is the abstract interface between
software and hardware. It defines the set of instructions a processor can
execute. Examples include RISC-V, ARM, and x86.

- The compiler generates instructions according to the ISA of the target
  hardware.
- The assembler converts those instructions into binary machine code.
- The hardware executes the binary code as electronic signals (logic 0 and 1)
  on flip-flops and logic gates.

### Role of HDL

**Hardware Description Language (HDL)** is used to describe the hardware
that implements the ISA. The flow from ISA to physical chip is:

```
ISA (Architecture specification)
   ↓  (HDL — e.g., Verilog / TL-Verilog)
RTL (Register Transfer Level description)
   ↓  (Synthesis)
Netlist (Logic gates)
   ↓  (Place & Route)
Physical Layout (GDSII — actual chip)
```


---

## Section 2: System Software, ISA, and Application Interaction

### Concept

Applications do not talk directly to hardware. The interaction goes through
layers of system software:

```
Application Software (e.g., Email, Stopwatch)
   ↓
Standard Libraries (stdio.h, etc.)
   ↓  API (Application Programming Interface)
Operating System
   ↓  System Call
ABI (Application Binary Interface)
   ↓  User ISA
ISA Layer (RISC-V / ARM / x86)
   ↓
RTL / Hardware
```

### Operating System Role

The OS handles:
- Memory management
- I/O operations
- Converting application-level function calls into hardware-executable
  instructions via the compiler and assembler

### Compiler and ISA

The **compiler** converts high-level code (C/C++) into ISA-specific assembly.
The syntax of generated instructions depends on the target architecture:
- RISC-V ISA → RISC-V assembly
- x86 ISA → x86 assembly
- ARM ISA → ARM assembly

### Assembler

The **assembler** converts assembly instructions into binary machine code
(1s and 0s), which directly maps to electronic signals in the hardware.

### Three Stages from Application to Chip

| Stage | Description |
|-------|-------------|
| ISA and Architecture | What the hardware needs to do |
| HDL Implementation | Writing it in a hardware-specific language |
| Physical Design | Converting HDL into actual gates and flip-flops |


---

## Section 3: Integer Number Representation

### Decimal vs Binary

Computers operate in binary (0s and 1s) while humans use decimal. A
conversion mechanism is needed between these two systems.

### Basic Definitions

| Term | Definition |
|------|-----------|
| Bit | Single binary digit: 0 or 1 |
| Byte | 8 bits |
| Word | 32 bits (4 bytes) |
| Double Word | 64 bits (8 bytes) |
| LSB | Least Significant Bit — rightmost bit (bit 0) |
| MSB | Most Significant Bit — leftmost bit (bit 63 for 64-bit) |

### Unsigned Number Representation

Using `n` bits, the number of representable patterns is `2^n`.

| Bits | Patterns | Range |
|------|---------|-------|
| 3 | 8 | 0 to 7 |
| 8 | 256 | 0 to 255 |
| 32 | 2^32 | 0 to 4,294,967,295 |
| 64 | 2^64 | 0 to 18,446,744,073,709,551,615 |

Maximum unsigned 64-bit value: **2^64 − 1**

### Signed Numbers and Two's Complement

RISC-V (and most modern architectures) uses **two's complement** to represent
negative numbers.

**Rules:**
1. If MSB = 0 → the number is **positive**
2. If MSB = 1 → the number is **negative**

**Converting a positive number to its negative equivalent:**
1. Write the number in binary
2. Invert all bits (1's complement)
3. Add 1 to the result

**Example — representing −5 in 8-bit two's complement:**
```
+5  =  0000 0101
Invert:  1111 1010
Add 1:   1111 1011  ← this is −5
```

### Range of Signed 64-bit Numbers (RV64)

| Category | Range |
|----------|-------|
| Positive | 0 to +2^63 − 1 |
| Negative | −2^63 to −1 |

The MSB carries a weight of **−2^63** in two's complement. All other bits
carry their normal positive weight.

**Converting a negative 64-bit number to decimal:**
1. Identify MSB = 1 (negative)
2. Invert all bits and add 1 to find the magnitude
3. The result is −(magnitude)

### Overflow

When arithmetic on unsigned 64-bit numbers exceeds `2^64 − 1`, an overflow
flag is triggered. Signed overflow occurs when the result exceeds the signed
range.


---

## Section 4: RISC-V GNU Toolchain — Lab

### Concept

The GNU toolchain for RISC-V converts C programs into RISC-V machine code.
The key tools are:

| Tool | Purpose |
|------|---------|
| `riscv64-unknown-elf-gcc` | C compiler for RISC-V |
| `riscv64-unknown-elf-objdump` | Disassembler — shows assembly from binary |
| `spike` | RISC-V ISA simulator |
| `pk` | Proxy kernel — minimal OS for spike |

### Compilation Flow

```
C source file (.c)
   ↓  riscv64-unknown-elf-gcc
Object file (.o) — RISC-V binary
   ↓  spike pk
Program execution output
```

### Key Compiler Flags

| Flag | Meaning |
|------|---------|
| `-ofast` | Aggressive optimisation |
| `-mabi=lp64` | 64-bit integer ABI, 64-bit long and pointers |
| `-march=rv64i` | Target: RV64I base integer ISA |
| `-o <output>` | Specify output filename |

### Lab Commands

```bash
# Open and edit the C source file
leafpad 1ton_custom.c &

# Compile C + Assembly with RISC-V GCC
riscv64-unknown-elf-gcc -ofast -mabi=lp64 -march=rv64i \
    -o 1ton_custom.o 1ton_custom.c load.S

# Run the program on the spike simulator
spike pk 1ton_custom.o

# Disassemble the binary to view RISC-V assembly
riscv64-unknown-elf-objdump -d 1ton_custom.o | less
```


---

## Section 5: PicoRV32 — Running on Actual RTL

### Concept

After verifying on the spike simulator, the same program can be run on an
actual RTL implementation of a RISC-V processor (PicoRV32) using a Verilog
testbench. This demonstrates the complete flow from C source to hardware
simulation.

### Lab Commands

```bash
# Clone the workshop collaterals repository
git clone https://github.com/kunalg123/risc_workshop_collaterals.git

# Navigate to the labs directory
cd risc_workshop_collaterals/labs

# List available files
ls -ltr

# Inspect the RTL and testbench files
vim picorv32.v
vim testbench.v
vim run.sh

# Make the simulation script executable and run it
chmod 777 run.sh
./run.sh

# View the generated firmware (hex output)
vim firmware.hex
vim firmware32.hex
```

### What These Files Do

| File | Purpose |
|------|---------|
| `picorv32.v` | RTL implementation of the PicoRV32 RISC-V CPU |
| `testbench.v` | Verilog testbench to drive the simulation |
| `run.sh` | Shell script: compiles C, converts to hex, runs simulation |
| `firmware.hex` | 64-bit hex firmware loaded into simulated memory |
| `firmware32.hex` | 32-bit hex version of the firmware |


---

## Key Concepts Summary

| Concept | Summary |
|---------|---------|
| ISA | Interface between software and hardware; defines instruction syntax |
| Compiler | Converts C to ISA-specific assembly |
| Assembler | Converts assembly to binary machine code |
| HDL | Describes hardware in code; synthesised into logic gates |
| Two's complement | Standard method to represent signed integers in binary |
| MSB = 0 | Positive number |
| MSB = 1 | Negative number |
| 64-bit signed range | −2^63 to +2^63 − 1 |
| 64-bit unsigned range | 0 to 2^64 − 1 |
| `spike` | RISC-V instruction-set simulator |
| `pk` | Proxy kernel — provides basic OS services to spike |

---

## References

- RISC-V ISA specification: https://riscv.org/technical/specifications/
- Workshop collaterals: https://github.com/kunalg123/risc_workshop_collaterals
- VSD MYTH Workshop: https://www.vlsisystemdesign.com
