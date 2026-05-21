# Day 4 — Building a RISC-V CPU Core (Single Cycle)

## Table of Contents
- [Overview](#overview)
- [Test Program](#test-program)
- [Implementation Plan](#implementation-plan)
- [Lab 1 — Next PC Logic](#lab-1--next-pc-logic)
- [Lab 2 — Instruction Fetch](#lab-2--instruction-fetch)
- [Lab 3 — Instruction Type Decode](#lab-3--instruction-type-decode)
- [Lab 4 — Instruction Immediate Decode](#lab-4--instruction-immediate-decode)
- [Lab 5 — Instruction Field Decode (Basic)](#lab-5--instruction-field-decode-basic)
- [Lab 6 — Instruction Field Decode with When Conditions](#lab-6--instruction-field-decode-with-when-conditions)
- [Lab 7 — Full Instruction Decode](#lab-7--full-instruction-decode)
- [Lab 8 — Register File Read](#lab-8--register-file-read)
- [Lab 9 — ALU](#lab-9--alu)
- [Lab 10 — Register File Write](#lab-10--register-file-write)
- [Lab 11 — Branches](#lab-11--branches)
- [Key Takeaways](#key-takeaways)

---

## Overview

Day 4 builds a **complete single-cycle RISC-V CPU** from scratch, one block at a time. Each lab adds one functional block and is verified in simulation before moving to the next. This is **test-driven development** applied to hardware — you confirm each piece works before building on top of it.

The final CPU at the end of Day 4 can:
- Fetch instructions from memory
- Decode all RV32I instruction types
- Read two source registers
- Execute arithmetic, logic, and shift operations
- Write results back to the register file
- Evaluate branch conditions and redirect the PC

**Architecture overview:**

```
@0                    @1                          @2
┌────────────┐        ┌────────────────────────────────────────────┐
│  PC Logic  │─$pc───►│  Fetch → Decode → RF Read → ALU → RF Write │
│  +4 / br   │◄───────│                            $taken_br        │
└────────────┘ >>1    └────────────────────────────────────────────┘
```

---

## Test Program

The same program is used throughout Days 4 and 5. It sums integers 1 through 9 and stores the result in register `x10`:

```asm
ADD   r10, r0,  r0    // x10 = 0  (initialize sum)
ADD   r14, r10, r0    // x14 = 0  (initialize accumulator)
ADDI  r12, r10, 1010  // x12 = 10 (loop limit, 1010 in binary = 10)
ADD   r13, r10, r0    // x13 = 0  (initialize counter i)
// loop:
ADD   r14, r13, r14   // x14 = x14 + i  (accumulate)
ADDI  r13, r13, 1     // x13 = x13 + 1  (increment counter)
BLT   r13, r12, -8    // if i < 10, branch back to loop
ADD   r10, r14, r0    // x10 = x14 (copy result to x10)
```

**Expected result:** `x10 = 1+2+3+...+9 = 45`

The passing condition used throughout:
```tlv
*passed = *cyc_cnt > 40;   // temporary — replaced with real check in Day 5
```

---

## Implementation Plan

The 7-step build order follows the data flow through the CPU:

```
Step 1 ──► PC Logic         "Where is the next instruction?"
Step 2 ──► Fetch            "Read it from instruction memory"
Step 3 ──► Decode           "What type is it? What fields does it have?"
Step 4 ──► RF Read          "Get the source register values"
Step 5 ──► ALU              "Compute the result"
Step 6 ──► RF Write         "Write result to destination register"
Step 7 ──► Branches         "Was it a branch? Where do we go next?"
```

Each step is a lab. Each lab has a screenshot from Makerchip simulation to confirm correct behaviour before proceeding.

---

## Lab 1 — Next PC Logic

### Concept

The **Program Counter (PC)** is a 32-bit register that holds the address of the instruction currently being fetched. After reset it starts at `0x00000000`. Every cycle it advances by 4 (because RISC-V instructions are 32-bit = 4 bytes, and memory is byte-addressed).

The key design question is: **which cycle does the PC change?**

In TL-Verilog, `>>1$reset` means "the value of `$reset` from the previous cycle". So the condition `>>1$reset ? 32'd0` means: "if we were in reset last cycle, start from address 0 now". This is correct — the first valid PC appears the cycle *after* reset deasserts.

```
reset: 1  1  0  0  0  0  0
pc:    X  X  0  4  8  12  16
```

### Why `+4` and not `+1`?

Memory is **byte-addressed**. One RISC-V instruction occupies 4 bytes (32 bits). Instruction 0 is at byte address 0, instruction 1 is at byte address 4, instruction 2 is at byte address 8, and so on. Incrementing by 1 would advance only one byte and land in the middle of an instruction.

### Code

```tlv
\m4_TLV_version 1d: tl-x.org
\SV
   m4_include_lib(['https://raw.githubusercontent.com/BalaDhinesh/RISC-V_MYTH_Workshop/master/tlv_lib/risc-v_shell_lib.tlv'])
\SV
   m4_makerchip_module
\TLV
   m4_asm(ADD, r10, r0, r0)
   m4_asm(ADD, r14, r10, r0)
   m4_asm(ADDI, r12, r10, 1010)
   m4_asm(ADD, r13, r10, r0)
   m4_asm(ADD, r14, r13, r14)
   m4_asm(ADDI, r13, r13, 1)
   m4_asm(BLT, r13, r12, 1111111111000)
   m4_asm(ADD, r10, r14, r0)

   m4_define_hier(['M4_IMEM'], M4_NUM_INSTRS)

   |cpu
      @0
         $reset = *reset;

         // If previous cycle was reset → go to address 0
         // Otherwise → advance by 4 bytes (one instruction)
         $pc[31:0] = >>1$reset
                     ? 32'd0
                     : >>1$pc + 32'd4;

         // Word-aligned address for instruction memory
         $imem_rd_addr[M4_IMEM_INDEX_CNT-1:0] = $pc[M4_IMEM_INDEX_CNT+1:2];

      @1
         $instr[31:0] = $imem_rd_data[31:0];

   *passed = *cyc_cnt > 40;
   *failed = 1'b0;

   |cpu
      m4+imem(@1)
   m4+cpu_viz(@4)

\SV
   endmodule
```

### Simulation Output

After reset deasserts, the PC waveform should show: `0 → 4 → 8 → 12 → 16 ...`

> 📸 `screenshots/day4/pc_couter_d.png`

---

## Lab 2 — Instruction Fetch

### Concept

**Fetching** means reading the 32-bit instruction stored at the current PC from **instruction memory (IMem)**. The IMem macro is pre-loaded with the assembled test program and exposes a simple interface:

| Signal | Direction | Meaning |
|--------|-----------|---------|
| `$imem_rd_en` | Input | Read enable — must be 1 to get data |
| `$imem_rd_addr` | Input | Word address of instruction to read |
| `$imem_rd_data[31:0]` | Output | 32-bit instruction returned |

### Why the address slicing `$pc[M4_IMEM_INDEX_CNT+1:2]`?

The PC is a **byte address**. The IMem is **word-addressed** (each entry is 4 bytes). We need to convert:

```
Byte address: 0x00, 0x04, 0x08, 0x0C ...
Word address:    0,    1,    2,    3 ...

Conversion: word_addr = byte_addr >> 2
         = byte_addr[MSB:2]   (drop the lowest 2 bits)
```

Bits `[1:0]` of the PC are always `00` for properly aligned instructions, so we simply strip them. We take only as many bits as needed to index the memory depth (`M4_IMEM_INDEX_CNT` bits).

### Code

```tlv
\m4_TLV_version 1d: tl-x.org
\SV
   m4_include_lib(['https://raw.githubusercontent.com/BalaDhinesh/RISC-V_MYTH_Workshop/master/tlv_lib/risc-v_shell_lib.tlv'])
\SV
   m4_makerchip_module
\TLV
   m4_asm(ADD, r10, r0, r0)
   m4_asm(ADD, r14, r10, r0)
   m4_asm(ADDI, r12, r10, 1010)
   m4_asm(ADD, r13, r10, r0)
   m4_asm(ADD, r14, r13, r14)
   m4_asm(ADDI, r13, r13, 1)
   m4_asm(BLT, r13, r12, 1111111111000)
   m4_asm(ADD, r10, r14, r0)

   m4_define_hier(['M4_IMEM'], M4_NUM_INSTRS)

   |cpu
      @0
         $reset = *reset;
         $pc[31:0] = >>1$reset
                     ? 32'd0
                     : >>1$pc + 32'd4;

         // Enable read every cycle except during reset
         $imem_rd_en = !$reset;
         // Convert byte PC to word address by dropping bits [1:0]
         $imem_rd_addr[M4_IMEM_INDEX_CNT-1:0] = $pc[M4_IMEM_INDEX_CNT+1:2];

      @1
         // Instruction arrives one cycle after the address is presented
         $instr[31:0] = $imem_rd_data[31:0];

   *passed = *cyc_cnt > 40;
   *failed = 1'b0;

   |cpu
      m4+imem(@1)
   m4+cpu_viz(@4)

\SV
   endmodule
```

### Simulation Output

`$instr` should show the binary encoding of the first instruction (`ADD r10, r0, r0`) on the first valid cycle. Check the Makerchip diagram view to confirm the IMem is wired up.

> 📸 `screenshots/day4/fetch_d.png`

---

## Lab 3 — Instruction Type Decode

### Concept

Before extracting any fields, we must know the **instruction format** — because the same bit positions mean different things in different formats. RISC-V has 6 formats:

| Type | Used for | Has `rd`? | Has `rs1`? | Has `rs2`? | Has `imm`? |
|------|----------|-----------|------------|------------|------------|
| R | Register ops (ADD, SUB, AND…) | ✅ | ✅ | ✅ | ❌ |
| I | Immediate ops, loads, JALR | ✅ | ✅ | ❌ | ✅ |
| S | Stores | ❌ | ✅ | ✅ | ✅ |
| B | Branches | ❌ | ✅ | ✅ | ✅ |
| U | LUI, AUIPC | ✅ | ❌ | ❌ | ✅ |
| J | JAL | ✅ | ❌ | ❌ | ✅ |

The format is determined by **bits `[6:2]`** of the instruction (bits `[1:0]` are always `11` for 32-bit instructions in RV32I, so they carry no information for decode).

The `==?` operator performs a **don't-care comparison** — a bit position marked `x` matches both `0` and `1`. This lets one comparison cover multiple opcodes that share the same format.

```
instr[6:2] ==? 5'b0000x   →  matches 00000 and 00001  (LOAD and LOAD-FP)
```

### Code

```tlv
\m4_TLV_version 1d: tl-x.org
\SV
   m4_include_lib(['https://raw.githubusercontent.com/BalaDhinesh/RISC-V_MYTH_Workshop/master/tlv_lib/risc-v_shell_lib.tlv'])
\SV
   m4_makerchip_module
\TLV
   m4_asm(ADD, r10, r0, r0)
   m4_asm(ADD, r14, r10, r0)
   m4_asm(ADDI, r12, r10, 1010)
   m4_asm(ADD, r13, r10, r0)
   m4_asm(ADD, r14, r13, r14)
   m4_asm(ADDI, r13, r13, 1)
   m4_asm(BLT, r13, r12, 1111111111000)
   m4_asm(ADD, r10, r14, r0)

   m4_define_hier(['M4_IMEM'], M4_NUM_INSTRS)

   |cpu
      @0
         $reset = *reset;
         $pc[31:0] = >>1$reset ? 32'd0 : >>1$pc + 32'd4;
         $imem_rd_en = !$reset;
         $imem_rd_addr[M4_IMEM_INDEX_CNT-1:0] = $pc[M4_IMEM_INDEX_CNT+1:2];
      @1
         $instr[31:0] = $imem_rd_data[31:0];

         // Identify instruction type from instr[6:2]
         // ==? is a don't-care comparison ('x' matches 0 or 1)
         $is_i_instr = $instr[6:2] ==? 5'b0000x ||   // LOAD, LOAD-FP
                       $instr[6:2] ==? 5'b001x0 ||   // MISC-MEM, OP-IMM, OP-IMM-32
                       $instr[6:2] ==? 5'b11001 ||   // JALR
                       $instr[6:2] ==? 5'b11100;     // SYSTEM

         $is_r_instr = $instr[6:2] ==? 5'b01011 ||   // AMO
                       $instr[6:2] ==? 5'b0110x ||   // OP, OP-32
                       $instr[6:2] ==? 5'b10100;     // OP-FP

         $is_s_instr = $instr[6:2] ==? 5'b0100x;     // STORE, STORE-FP

         $is_b_instr = $instr[6:2] ==? 5'b11000;     // BRANCH

         $is_j_instr = $instr[6:2] ==? 5'b11011;     // JAL

         $is_u_instr = $instr[6:2] ==? 5'b0x101;     // AUIPC, LUI

         `BOGUS_USE($is_i_instr $is_r_instr $is_s_instr
                    $is_b_instr $is_j_instr $is_u_instr)

   *passed = *cyc_cnt > 40;
   *failed = 1'b0;

   |cpu
      m4+imem(@1)
   m4+cpu_viz(@4)

\SV
   endmodule
```

### Simulation Output

In the waveform, verify that `$is_r_instr` is high for ADD instructions and `$is_b_instr` is high for the BLT instruction in the test program.

> 📸 `screenshots/day4/incrst_de_d.png`

---

## Lab 4 — Instruction Immediate Decode

### Concept

Immediates are **constants embedded directly in the instruction encoding**. Because 32-bit instructions don't have room for a full 32-bit immediate, the immediate is stored in fewer bits and **sign-extended** to 32 bits at decode time.

Sign extension works by replicating the **most significant bit** of the immediate field (always `instr[31]`) to fill the upper bits of the 32-bit value. This preserves the two's complement value of the constant.

The immediate bits are **scattered differently** across the instruction word depending on the format — this is deliberate ISA design to keep the sign bit always in `instr[31]` and to minimise mux hardware in the decoder.

| Format | Immediate bits in the 32-bit word | Sign bit |
|--------|------------------------------------|----------|
| I | `inst[31:20]` | `inst[31]` |
| S | `inst[31:25]`, `inst[11:7]` | `inst[31]` |
| B | `inst[31]`, `inst[7]`, `inst[30:25]`, `inst[11:8]`, implicit `0` | `inst[31]` |
| U | `inst[31:12]`, implicit `12'b0` | `inst[31]` |
| J | `inst[31]`, `inst[19:12]`, `inst[20]`, `inst[30:21]`, implicit `0` | `inst[31]` |

Note that B and J immediates have an implicit `0` as the LSB — branches and jumps always target even addresses (2-byte aligned for compressed instructions, 4-byte for standard).

### Code

```tlv
\m4_TLV_version 1d: tl-x.org
\SV
   m4_include_lib(['https://raw.githubusercontent.com/BalaDhinesh/RISC-V_MYTH_Workshop/master/tlv_lib/risc-v_shell_lib.tlv'])
\SV
   m4_makerchip_module
\TLV
   m4_asm(ADD, r10, r0, r0)
   m4_asm(ADD, r14, r10, r0)
   m4_asm(ADDI, r12, r10, 1010)
   m4_asm(ADD, r13, r10, r0)
   m4_asm(ADD, r14, r13, r14)
   m4_asm(ADDI, r13, r13, 1)
   m4_asm(BLT, r13, r12, 1111111111000)
   m4_asm(ADD, r10, r14, r0)

   m4_define_hier(['M4_IMEM'], M4_NUM_INSTRS)

   |cpu
      @0
         $reset = *reset;
         $pc[31:0] = >>1$reset ? 32'd0 : >>1$pc + 32'd4;
         $imem_rd_en = !$reset;
         $imem_rd_addr[M4_IMEM_INDEX_CNT-1:0] = $pc[M4_IMEM_INDEX_CNT+1:2];
      @1
         $instr[31:0] = $imem_rd_data[31:0];

         // Type decode (from Lab 3)
         $is_i_instr = $instr[6:2] ==? 5'b0000x || $instr[6:2] ==? 5'b001x0 ||
                       $instr[6:2] ==? 5'b11001 || $instr[6:2] ==? 5'b11100;
         $is_r_instr = $instr[6:2] ==? 5'b01011 || $instr[6:2] ==? 5'b0110x ||
                       $instr[6:2] ==? 5'b10100;
         $is_s_instr = $instr[6:2] ==? 5'b0100x;
         $is_b_instr = $instr[6:2] ==? 5'b11000;
         $is_j_instr = $instr[6:2] ==? 5'b11011;
         $is_u_instr = $instr[6:2] ==? 5'b0x101;

         // Assemble 32-bit sign-extended immediate from scattered bits
         // {N{bit}} replicates 'bit' N times for sign extension
         $imm[31:0] =
            $is_i_instr ? { {21{$instr[31]}}, $instr[30:20] } :

            $is_s_instr ? { {21{$instr[31]}}, $instr[30:25], $instr[11:7] } :

            $is_b_instr ? { {20{$instr[31]}}, $instr[7],
                            $instr[30:25], $instr[11:8], 1'b0 } :

            $is_u_instr ? { $instr[31:12], 12'b0 } :

            $is_j_instr ? { {12{$instr[31]}}, $instr[19:12], $instr[20],
                            $instr[30:21], 1'b0 } :

                          32'b0;   // R-type: no immediate

         `BOGUS_USE($imm)

   *passed = *cyc_cnt > 40;
   *failed = 1'b0;

   |cpu
      m4+imem(@1)
   m4+cpu_viz(@4)

\SV
   endmodule
```

### Simulation Output

Check `$imm` for an ADDI instruction — for `ADDI r12, r10, 10`, you should see `$imm = 32'd10`. For the BLT branch offset, you should see a negative value (sign-extended backwards offset).

> 📸 `screenshots/day4/lab2_de_d.png`

---

## Lab 5 — Instruction Field Decode (Basic)

### Concept

Now extract the register indices and function codes from the instruction. These fields are at **fixed bit positions** across the formats that use them, which is another deliberate RISC-V ISA design choice to reduce hardware.

| Field | Bits | Meaning |
|-------|------|---------|
| `rd` | `[11:7]` | Destination register index (0–31) |
| `rs1` | `[19:15]` | Source register 1 index (0–31) |
| `rs2` | `[24:20]` | Source register 2 index (0–31) |
| `funct3` | `[14:12]` | 3-bit function code (refines opcode) |
| `funct7` | `[31:25]` | 7-bit function code (only in R-type) |
| `opcode` | `[6:0]` | Instruction class |

### Code

```tlv
\m4_TLV_version 1d: tl-x.org
\SV
   m4_include_lib(['https://raw.githubusercontent.com/BalaDhinesh/RISC-V_MYTH_Workshop/master/tlv_lib/risc-v_shell_lib.tlv'])
\SV
   m4_makerchip_module
\TLV
   m4_asm(ADD, r10, r0, r0)
   m4_asm(ADD, r14, r10, r0)
   m4_asm(ADDI, r12, r10, 1010)
   m4_asm(ADD, r13, r10, r0)
   m4_asm(ADD, r14, r13, r14)
   m4_asm(ADDI, r13, r13, 1)
   m4_asm(BLT, r13, r12, 1111111111000)
   m4_asm(ADD, r10, r14, r0)

   m4_define_hier(['M4_IMEM'], M4_NUM_INSTRS)

   |cpu
      @0
         $reset = *reset;
         $pc[31:0] = >>1$reset ? 32'd0 : >>1$pc + 32'd4;
         $imem_rd_en = !$reset;
         $imem_rd_addr[M4_IMEM_INDEX_CNT-1:0] = $pc[M4_IMEM_INDEX_CNT+1:2];
      @1
         $instr[31:0] = $imem_rd_data[31:0];

         // Type decode
         $is_i_instr = $instr[6:2] ==? 5'b0000x || $instr[6:2] ==? 5'b001x0 ||
                       $instr[6:2] ==? 5'b11001 || $instr[6:2] ==? 5'b11100;
         $is_r_instr = $instr[6:2] ==? 5'b01011 || $instr[6:2] ==? 5'b0110x ||
                       $instr[6:2] ==? 5'b10100;
         $is_s_instr = $instr[6:2] ==? 5'b0100x;
         $is_b_instr = $instr[6:2] ==? 5'b11000;
         $is_j_instr = $instr[6:2] ==? 5'b11011;
         $is_u_instr = $instr[6:2] ==? 5'b0x101;

         // Immediate decode
         $imm[31:0] =
            $is_i_instr ? { {21{$instr[31]}}, $instr[30:20] } :
            $is_s_instr ? { {21{$instr[31]}}, $instr[30:25], $instr[11:7] } :
            $is_b_instr ? { {20{$instr[31]}}, $instr[7], $instr[30:25], $instr[11:8], 1'b0 } :
            $is_u_instr ? { $instr[31:12], 12'b0 } :
            $is_j_instr ? { {12{$instr[31]}}, $instr[19:12], $instr[20], $instr[30:21], 1'b0 } :
                          32'b0;

         // Extract fixed-position fields directly from the instruction word
         $rs2[4:0]    = $instr[24:20];
         $rs1[4:0]    = $instr[19:15];
         $rd[4:0]     = $instr[11:7];
         $funct3[2:0] = $instr[14:12];
         $funct7[6:0] = $instr[31:25];
         $opcode[6:0] = $instr[6:0];

         `BOGUS_USE($rs1 $rs2 $rd $funct3 $funct7 $opcode)

   *passed = *cyc_cnt > 40;
   *failed = 1'b0;

   |cpu
      m4+imem(@1)
   m4+cpu_viz(@4)

\SV
   endmodule
```

### Simulation Output

Verify that for the first ADD instruction, `$rs1 = 10` (r10), `$rs2 = 0` (r0), and `$rd = 10`.

> 📸 `screenshots/day4/Instruction Field Decode (basic).png`

---

## Lab 6 — Instruction Field Decode with When Conditions

### Concept

The basic field extraction works, but it has a problem: for a U-type instruction (like LUI), there is no `rs2` — those bits in the instruction word are part of the immediate, not a register index. Extracting `rs2` for a U-type would produce a meaningless value.

TL-Verilog's `?$condition` **when blocks** solve this cleanly:

```tlv
?$rs2_valid
   $rs2[4:0] = $instr[24:20];
```

When `$rs2_valid` is false, `$rs2` is **X (don't-care)**. This has two benefits:
1. The simulator flags unintended use of X values, helping catch bugs
2. Synthesis tools can optimize away logic that feeds into don't-care signals, reducing power

### Validity conditions for each field:

| Field | Valid when |
|-------|-----------|
| `rs1` | R, I, S, B type |
| `rs2` | R, S, B type |
| `rd` | R, I, U, J type |
| `funct3` | R, I, S, B type |
| `funct7` | R type only |
| `opcode` | Always |

### Code

```tlv
\m4_TLV_version 1d: tl-x.org
\SV
   m4_include_lib(['https://raw.githubusercontent.com/BalaDhinesh/RISC-V_MYTH_Workshop/master/tlv_lib/risc-v_shell_lib.tlv'])
\SV
   m4_makerchip_module
\TLV
   m4_asm(ADD, r10, r0, r0)
   m4_asm(ADD, r14, r10, r0)
   m4_asm(ADDI, r12, r10, 1010)
   m4_asm(ADD, r13, r10, r0)
   m4_asm(ADD, r14, r13, r14)
   m4_asm(ADDI, r13, r13, 1)
   m4_asm(BLT, r13, r12, 1111111111000)
   m4_asm(ADD, r10, r14, r0)

   m4_define_hier(['M4_IMEM'], M4_NUM_INSTRS)

   |cpu
      @0
         $reset = *reset;
         $pc[31:0] = >>1$reset ? 32'd0 : >>1$pc + 32'd4;
         $imem_rd_en = !$reset;
         $imem_rd_addr[M4_IMEM_INDEX_CNT-1:0] = $pc[M4_IMEM_INDEX_CNT+1:2];
      @1
         $instr[31:0] = $imem_rd_data[31:0];

         // Type decode
         $is_i_instr = $instr[6:2] ==? 5'b0000x || $instr[6:2] ==? 5'b001x0 ||
                       $instr[6:2] ==? 5'b11001 || $instr[6:2] ==? 5'b11100;
         $is_r_instr = $instr[6:2] ==? 5'b01011 || $instr[6:2] ==? 5'b0110x ||
                       $instr[6:2] ==? 5'b10100;
         $is_s_instr = $instr[6:2] ==? 5'b0100x;
         $is_b_instr = $instr[6:2] ==? 5'b11000;
         $is_j_instr = $instr[6:2] ==? 5'b11011;
         $is_u_instr = $instr[6:2] ==? 5'b0x101;

         // Immediate decode
         $imm[31:0] =
            $is_i_instr ? { {21{$instr[31]}}, $instr[30:20] } :
            $is_s_instr ? { {21{$instr[31]}}, $instr[30:25], $instr[11:7] } :
            $is_b_instr ? { {20{$instr[31]}}, $instr[7], $instr[30:25], $instr[11:8], 1'b0 } :
            $is_u_instr ? { $instr[31:12], 12'b0 } :
            $is_j_instr ? { {12{$instr[31]}}, $instr[19:12], $instr[20], $instr[30:21], 1'b0 } :
                          32'b0;

         // Each field is only valid for formats that actually contain it
         $rs1_valid    = $is_r_instr || $is_i_instr || $is_s_instr || $is_b_instr;
         $rs2_valid    = $is_r_instr || $is_s_instr || $is_b_instr;
         $rd_valid     = $is_r_instr || $is_i_instr || $is_u_instr || $is_j_instr;
         $funct3_valid = $is_r_instr || $is_i_instr || $is_s_instr || $is_b_instr;
         $funct7_valid = $is_r_instr;

         // ?$condition blocks: signal is X (don't-care) when condition is false
         ?$rs1_valid
            $rs1[4:0]    = $instr[19:15];
         ?$rs2_valid
            $rs2[4:0]    = $instr[24:20];
         ?$rd_valid
            $rd[4:0]     = $instr[11:7];
         ?$funct3_valid
            $funct3[2:0] = $instr[14:12];
         ?$funct7_valid
            $funct7[6:0] = $instr[31:25];

         $opcode[6:0] = $instr[6:0];   // always valid

   *passed = *cyc_cnt > 40;
   *failed = 1'b0;

   |cpu
      m4+imem(@1)
   m4+cpu_viz(@4)

\SV
   endmodule
```

### Simulation Output

With when conditions, signals that are X in the waveform are shown differently from valid 0s — this makes simulation debugging much cleaner.

> 📸 `screenshots/day4/instruction decode with when.png`

---

## Lab 7 — Full Instruction Decode

### Concept

Now we identify **every individual instruction** by combining `funct7[5]`, `funct3`, and `opcode` into an 11-bit decode vector `$dec_bits`.

**Why only `funct7[5]` and not all 7 bits?**
In RV32I, `funct7[5]` is the only bit in funct7 that distinguishes instruction pairs: `ADD` vs `SUB`, and `SRL` vs `SRA`. Using all 7 bits would require a wider comparator for no benefit. The other bits of funct7 are either always zero or part of the shift amount.

```
$dec_bits = {funct7[5], funct3[2:0], opcode[6:0]}  →  11 bits total
```

For instructions where funct7 doesn't apply (I-type, branches, etc.), we use `x` (don't-care) for that bit in the comparison pattern.

### Code

```tlv
\m4_TLV_version 1d: tl-x.org
\SV
   m4_include_lib(['https://raw.githubusercontent.com/BalaDhinesh/RISC-V_MYTH_Workshop/master/tlv_lib/risc-v_shell_lib.tlv'])
\SV
   m4_makerchip_module
\TLV
   m4_asm(ADD, r10, r0, r0)
   m4_asm(ADD, r14, r10, r0)
   m4_asm(ADDI, r12, r10, 1010)
   m4_asm(ADD, r13, r10, r0)
   m4_asm(ADD, r14, r13, r14)
   m4_asm(ADDI, r13, r13, 1)
   m4_asm(BLT, r13, r12, 1111111111000)
   m4_asm(ADD, r10, r14, r0)

   m4_define_hier(['M4_IMEM'], M4_NUM_INSTRS)

   |cpu
      @0
         $reset = *reset;
         $pc[31:0] = (>>1$reset) ? 32'd0 : (>>1$pc + 32'd4);

      @1
         $imem_rd_en = !$reset;
         $imem_rd_addr[M4_IMEM_INDEX_CNT-1:0] = $pc[M4_IMEM_INDEX_CNT+1:2];
         $instr[31:0] = $imem_rd_data[31:0];

         // Type decode
         $is_i_instr = $instr[6:2] ==? 5'b0000x || $instr[6:2] ==? 5'b001x0 ||
                       $instr[6:2] ==? 5'b11001 || $instr[6:2] ==? 5'b11100;
         $is_r_instr = $instr[6:2] ==? 5'b01011 || $instr[6:2] ==? 5'b0110x ||
                       $instr[6:2] ==? 5'b10100;
         $is_s_instr = $instr[6:2] ==? 5'b0100x;
         $is_b_instr = $instr[6:2] ==? 5'b11000;
         $is_j_instr = $instr[6:2] ==? 5'b11011;
         $is_u_instr = $instr[6:2] ==? 5'b0x101;

         // Immediate decode
         $imm[31:0] =
            $is_i_instr ? { {21{$instr[31]}}, $instr[30:20] } :
            $is_s_instr ? { {21{$instr[31]}}, $instr[30:25], $instr[11:7] } :
            $is_b_instr ? { {20{$instr[31]}}, $instr[7], $instr[30:25], $instr[11:8], 1'b0 } :
            $is_u_instr ? { $instr[31:12], 12'b0 } :
            $is_j_instr ? { {12{$instr[31]}}, $instr[19:12], $instr[20], $instr[30:21], 1'b0 } :
                          32'b0;

         // Field validity and when-conditional extraction
         $rs1_valid    = $is_r_instr || $is_i_instr || $is_s_instr || $is_b_instr;
         $rs2_valid    = $is_r_instr || $is_s_instr || $is_b_instr;
         $rd_valid     = $is_r_instr || $is_i_instr || $is_u_instr || $is_j_instr;
         $funct3_valid = $is_r_instr || $is_i_instr || $is_s_instr || $is_b_instr;
         $funct7_valid = $is_r_instr;

         ?$rs1_valid    $rs1[4:0]    = $instr[19:15];
         ?$rs2_valid    $rs2[4:0]    = $instr[24:20];
         ?$rd_valid     $rd[4:0]     = $instr[11:7];
         ?$funct3_valid $funct3[2:0] = $instr[14:12];
         ?$funct7_valid $funct7[6:0] = $instr[31:25];
         $opcode[6:0] = $instr[6:0];

         // 11-bit decode vector: {funct7[5], funct3, opcode}
         // funct7[5] is the only funct7 bit that distinguishes instruction variants
         $dec_bits[10:0] = {$funct7[5], $funct3, $opcode};

         // ── Branches (opcode 1100011) ─────────────────────────────────────────
         $is_beq  = $dec_bits ==? 11'bx_000_1100011;  // branch if equal
         $is_bne  = $dec_bits ==? 11'bx_001_1100011;  // branch if not equal
         $is_blt  = $dec_bits ==? 11'bx_100_1100011;  // branch if less than (signed)
         $is_bge  = $dec_bits ==? 11'bx_101_1100011;  // branch if >= (signed)
         $is_bltu = $dec_bits ==? 11'bx_110_1100011;  // branch if < (unsigned)
         $is_bgeu = $dec_bits ==? 11'bx_111_1100011;  // branch if >= (unsigned)

         // ── Immediate arithmetic (opcode 0010011) ────────────────────────────
         $is_addi  = $dec_bits ==? 11'bx_000_0010011;
         $is_slti  = $dec_bits ==? 11'bx_010_0010011;
         $is_sltiu = $dec_bits ==? 11'bx_011_0010011;
         $is_xori  = $dec_bits ==? 11'bx_100_0010011;
         $is_ori   = $dec_bits ==? 11'bx_110_0010011;
         $is_andi  = $dec_bits ==? 11'bx_111_0010011;
         $is_slli  = $dec_bits ==? 11'b0_001_0010011;
         $is_srli  = $dec_bits ==? 11'b0_101_0010011;
         $is_srai  = $dec_bits ==? 11'b1_101_0010011;  // funct7[5]=1 distinguishes from SRLI

         // ── Register arithmetic (opcode 0110011) ────────────────────────────
         // funct7[5]=0 → standard | funct7[5]=1 → alternate (SUB, SRA)
         $is_add  = $dec_bits ==? 11'b0_000_0110011;
         $is_sub  = $dec_bits ==? 11'b1_000_0110011;  // same funct3/opcode as ADD
         $is_sll  = $dec_bits ==? 11'b0_001_0110011;
         $is_slt  = $dec_bits ==? 11'b0_010_0110011;
         $is_sltu = $dec_bits ==? 11'b0_011_0110011;
         $is_xor  = $dec_bits ==? 11'b0_100_0110011;
         $is_srl  = $dec_bits ==? 11'b0_101_0110011;
         $is_sra  = $dec_bits ==? 11'b1_101_0110011;  // same funct3/opcode as SRL
         $is_or   = $dec_bits ==? 11'b0_110_0110011;
         $is_and  = $dec_bits ==? 11'b0_111_0110011;

         // ── Upper immediate (no funct3/funct7 → use x for those) ────────────
         $is_lui   = $dec_bits ==? 11'bx_xxx_0110111;
         $is_auipc = $dec_bits ==? 11'bx_xxx_0010111;

         // ── Jumps ─────────────────────────────────────────────────────────────
         $is_jal  = $dec_bits ==? 11'bx_xxx_1101111;
         $is_jalr = $dec_bits ==? 11'bx_000_1100111;

         `BOGUS_USE($is_beq $is_bne $is_blt $is_bge $is_bltu $is_bgeu
                    $is_addi $is_slti $is_sltiu $is_xori $is_ori $is_andi
                    $is_slli $is_srli $is_srai
                    $is_add $is_sub $is_sll $is_slt $is_sltu
                    $is_xor $is_srl $is_sra $is_or $is_and
                    $is_lui $is_auipc $is_jal $is_jalr)

   *passed = *cyc_cnt > 40;
   *failed = 1'b0;

   |cpu
      m4+imem(@1)
   m4+cpu_viz(@4)

\SV
   endmodule
```

### Decode Bit Reference Table

| Instruction | `funct7[5]` | `funct3` | `opcode` |
|-------------|-------------|----------|----------|
| ADD | 0 | 000 | 0110011 |
| SUB | 1 | 000 | 0110011 |
| ADDI | x | 000 | 0010011 |
| BEQ | x | 000 | 1100011 |
| BNE | x | 001 | 1100011 |
| BLT | x | 100 | 1100011 |
| BGE | x | 101 | 1100011 |
| LUI | x | xxx | 0110111 |
| JAL | x | xxx | 1101111 |

### Simulation Output

Verify `$is_add` goes high for ADD instructions, `$is_addi` for ADDI, and `$is_blt` for the BLT in the test program.

> 📸 `screenshots/day4/decode_dbits.png`

---

