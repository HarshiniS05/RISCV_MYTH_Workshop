\m4_TLV_version 1d: tl-x.org
\SV
   m4_include_lib(['https://raw.githubusercontent.com/BalaDhinesh/RISC-V_MYTH_Workshop/master/tlv_lib/risc-v_shell_lib.tlv'])
\SV
   m4_makerchip_module
\TLV
   m4_asm(ADD,  r10, r0,  r0)
   m4_asm(ADD,  r14, r10, r0)
   m4_asm(ADDI, r12, r10, 1010)
   m4_asm(ADD,  r13, r10, r0)
   m4_asm(ADD,  r14, r13, r14)
   m4_asm(ADDI, r13, r13, 1)
   m4_asm(BLT,  r13, r12, 1111111111000)
   m4_asm(ADD,  r10, r14, r0)
   m4_asm(SW,   r0,  r10, 10000)
   m4_asm(LW,   r17, r0,  10000)

   m4_define_hier(['M4_IMEM'], M4_NUM_INSTRS)

   |cpu
      @0
         $reset = *reset;

         // Slide 53: PC selects JAL vs JALR target
         $pc[31:0] = >>1$reset
                     ? 32'd0
                     : >>3$valid_taken_br
                       ? >>3$br_tgt_pc
                       : >>3$valid_load
                         ? >>3$inc_pc
                         : >>3$valid_jump && >>3$is_jal
                           ? >>3$br_tgt_pc
                           : >>3$valid_jump && >>3$is_jalr
                             ? >>3$jalr_tgt_pc
                             : >>1$pc + 32'd4;

         $imem_rd_en = !$reset;
         $imem_rd_addr[M4_IMEM_INDEX_CNT-1:0] = $pc[M4_IMEM_INDEX_CNT+1:2];

      @1
         $instr[31:0] = $imem_rd_data[31:0];
         $inc_pc[31:0] = $pc + 32'd4;

         $is_i_instr = $instr[6:2] ==? 5'b0000x ||
                       $instr[6:2] ==? 5'b001x0 ||
                       $instr[6:2] ==? 5'b11001 ||
                       $instr[6:2] ==? 5'b11100;
         $is_r_instr = $instr[6:2] ==? 5'b01011 ||
                       $instr[6:2] ==? 5'b0110x ||
                       $instr[6:2] ==? 5'b10100;
         $is_s_instr = $instr[6:2] ==? 5'b0100x;
         $is_b_instr = $instr[6:2] ==? 5'b11000;
         $is_j_instr = $instr[6:2] ==? 5'b11011;
         $is_u_instr = $instr[6:2] ==? 5'b0x101;

         // Slide 53: define is_jump
         $is_jump = $is_jal || $is_jalr;

         $imm[31:0] = $is_i_instr ? { {21{$instr[31]}}, $instr[30:20] } :
                      $is_s_instr ? { {21{$instr[31]}}, $instr[30:25], $instr[11:7] } :
                      $is_b_instr ? { {20{$instr[31]}}, $instr[7], $instr[30:25], $instr[11:8], 1'b0 } :
                      $is_u_instr ? { $instr[31:12], 12'b0 } :
                      $is_j_instr ? { {12{$instr[31]}}, $instr[19:12], $instr[20], $instr[30:21], 1'b0 } :
                                    32'b0;

         $rs1_valid    = $is_r_instr || $is_i_instr || $is_s_instr || $is_b_instr;
         $rs2_valid    = $is_r_instr || $is_s_instr || $is_b_instr;
         $rd_valid     = $is_r_instr || $is_i_instr || $is_u_instr || $is_j_instr;
         $funct3_valid = $is_r_instr || $is_i_instr || $is_s_instr || $is_b_instr;
         $funct7_valid = $is_r_instr;

         ?$rs1_valid
            $rs1[4:0] = $instr[19:15];
         ?$rs2_valid
            $rs2[4:0] = $instr[24:20];
         ?$rd_valid
            $rd[4:0]  = $instr[11:7];
         ?$funct3_valid
            $funct3[2:0] = $instr[14:12];
         ?$funct7_valid
            $funct7[6:0] = $instr[31:25];

         $opcode[6:0] = $instr[6:0];
         $dec_bits[10:0] = {$funct7[5], $funct3, $opcode};

         $is_beq  = $dec_bits ==? 11'bx_000_1100011;
         $is_bne  = $dec_bits ==? 11'bx_001_1100011;
         $is_blt  = $dec_bits ==? 11'bx_100_1100011;
         $is_bge  = $dec_bits ==? 11'bx_101_1100011;
         $is_bltu = $dec_bits ==? 11'bx_110_1100011;
         $is_bgeu = $dec_bits ==? 11'bx_111_1100011;
         $is_addi  = $dec_bits ==? 11'bx_000_0010011;
         $is_andi  = $dec_bits ==? 11'bx_111_0010011;
         $is_ori   = $dec_bits ==? 11'bx_110_0010011;
         $is_xori  = $dec_bits ==? 11'bx_100_0010011;
         $is_slli  = $dec_bits ==? 11'b0_001_0010011;
         $is_srli  = $dec_bits ==? 11'b0_101_0010011;
         $is_srai  = $dec_bits ==? 11'b1_101_0010011;
         $is_slti  = $dec_bits ==? 11'bx_010_0010011;
         $is_sltiu = $dec_bits ==? 11'bx_011_0010011;
         $is_add  = $dec_bits ==? 11'b0_000_0110011;
         $is_sub  = $dec_bits ==? 11'b1_000_0110011;
         $is_and  = $dec_bits ==? 11'b0_111_0110011;
         $is_or   = $dec_bits ==? 11'b0_110_0110011;
         $is_xor  = $dec_bits ==? 11'b0_100_0110011;
         $is_sll  = $dec_bits ==? 11'b0_001_0110011;
         $is_srl  = $dec_bits ==? 11'b0_101_0110011;
         $is_sra  = $dec_bits ==? 11'b1_101_0110011;
         $is_slt  = $dec_bits ==? 11'b0_010_0110011;
         $is_sltu = $dec_bits ==? 11'b0_011_0110011;
         $is_lui   = $dec_bits ==? 11'bx_xxx_0110111;
         $is_auipc = $dec_bits ==? 11'bx_xxx_0010111;
         $is_jal   = $dec_bits ==? 11'bx_xxx_1101111;
         $is_jalr  = $dec_bits ==? 11'bx_000_1100111;
         $is_load  = $opcode == 7'b0000011;

         `BOGUS_USE($is_beq $is_bne $is_blt $is_bge $is_bltu $is_bgeu
                    $is_andi $is_ori $is_xori $is_slli $is_srli $is_srai
                    $is_slti $is_sltiu $is_sub $is_and $is_or $is_xor
                    $is_sll $is_srl $is_sra $is_slt $is_sltu $is_lui
                    $is_auipc $is_jal $is_jalr)

      @2
         $rf_rd_en1         = $rs1_valid;
         $rf_rd_index1[4:0] = $rs1;
         $rf_rd_en2         = $rs2_valid;
         $rf_rd_index2[4:0] = $rs2;

         $src1_value[31:0] =
              (>>1$rf_wr_en && (>>1$rd == $rs1)) ? >>1$result :
              (>>2$rf_wr_en && (>>2$rd == $rs1)) ? >>2$result :
                                                   $rf_rd_data1;
         $src2_value[31:0] =
              (>>1$rf_wr_en && (>>1$rd == $rs2)) ? >>1$result :
              (>>2$rf_wr_en && (>>2$rd == $rs2)) ? >>2$result :
                                                   $rf_rd_data2;

         $sltu_rslt  = $src1_value < $src2_value;
         $sltiu_rslt = $src1_value < $imm;

         $result[31:0] =
              $is_addi  ? $src1_value + $imm :
              $is_andi  ? $src1_value & $imm :
              $is_ori   ? $src1_value | $imm :
              $is_xori  ? $src1_value ^ $imm :
              $is_slli  ? $src1_value << $imm[5:0] :
              $is_srli  ? $src1_value >> $imm[5:0] :
              $is_srai  ? { {32{$src1_value[31]}}, $src1_value } >> $imm[4:0] :
              $is_slti  ? ($src1_value[31] == $imm[31]) ? $sltiu_rslt : {31'b0, $src1_value[31]} :
              $is_sltiu ? $sltiu_rslt :
              $is_add   ? $src1_value + $src2_value :
              $is_sub   ? $src1_value - $src2_value :
              $is_and   ? $src1_value & $src2_value :
              $is_or    ? $src1_value | $src2_value :
              $is_xor   ? $src1_value ^ $src2_value :
              $is_sll   ? $src1_value << $src2_value[4:0] :
              $is_srl   ? $src1_value >> $src2_value[4:0] :
              $is_sra   ? { {32{$src1_value[31]}}, $src1_value } >> $src2_value[4:0] :
              $is_slt   ? ($src1_value[31] == $src2_value[31]) ? $sltu_rslt : {31'b0, $src1_value[31]} :
              $is_sltu  ? $sltu_rslt :
              $is_lui   ? {$imm[31:12], 12'b0} :
              $is_auipc ? $pc + $imm :
              $is_jal   ? $pc + 32'd4 :
              $is_jalr  ? $pc + 32'd4 :
              ($is_load || $is_s_instr) ? $src1_value + $imm :
                           32'bx;

         $br_tgt_pc[31:0]   = $pc + $imm;
         // Slide 53: JALR target = SRC1 + IMM
         $jalr_tgt_pc[31:0] = $src1_value + $imm;

         $taken_br = $is_beq  ? ($src1_value == $src2_value) :
                     $is_bne  ? ($src1_value != $src2_value) :
                     $is_blt  ? (($src1_value < $src2_value) ^ ($src1_value[31] != $src2_value[31])) :
                     $is_bge  ? (($src1_value >= $src2_value) ^ ($src1_value[31] != $src2_value[31])) :
                     $is_bltu ? ($src1_value < $src2_value) :
                     $is_bgeu ? ($src1_value >= $src2_value) :
                                1'b0;

         $valid_load     = $valid && $is_load;
         // Slide 53: jump creates 2 invalid shadow cycles
         $valid_jump     = $valid && $is_jump;
         $valid          = !(>>1$valid_taken_br || >>2$valid_taken_br ||
                             >>1$valid_load     || >>2$valid_load     ||
                             >>1$valid_jump     || >>2$valid_jump);
         $valid_taken_br = $valid && $taken_br;

      @3
         $rf_wr_en         = ($valid && $rd_valid && ($rd != 5'b00000)) ||
                             >>2$valid_load;
         $rf_wr_index[4:0] = >>2$valid_load ? >>2$rd      : $rd;
         $rf_wr_data[31:0] = >>2$valid_load ? >>2$ld_data : $result;

         $dmem_addr[3:0]     = $result[5:2];
         $dmem_wr_en         = $valid && $is_s_instr;
         $dmem_wr_data[31:0] = $src2_value;
         $dmem_rd_en         = $is_load;

      @5
         $ld_data[31:0] = $dmem_rd_data[31:0];

   *passed = |cpu/xreg[17]>>5$value == (1+2+3+4+5+6+7+8+9);
   *failed = 1'b0;

   |cpu
      m4+imem(@1)
      m4+rf(@2, @3)
      m4+dmem(@4)
   m4+cpu_viz(@4)

\SV
   endmodule
