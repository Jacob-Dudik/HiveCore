/**************************************************************************************************
* Module Name    : fu_branch
* Author         : Jacob Dudik
* Creation Date  : 08/16/2026
* Last edit Date : 08/16/2026
* Description    : Branch Functional Unit:
*                  Computes branch targets and branch conditions for PC related instructions.
**************************************************************************************************/


`ifndef FU_BRANCH
`define FU_BRANCH
module fu_branch
  import core_pkg::*;
  import interface_struct_pkg::*;
  (
    // ========= Inputs ==========
    input  decode_execute_if_t dec_ex_i,

    // ========= Outputs =========
    output fu_branch_out_t     fu_branch_out_o
  );

  // ============================================
  //         Internal Signals
  // ============================================
  logic [63:0] imm_sext;

  // Sign extension of standard 20-bit immediate to 64 bits
  assign imm_sext   = {{44{dec_ex_i.imm[19]}}, dec_ex_i.imm};

  // ============================================
  //         Branch Execution Logic
  // ============================================
  always_comb begin
    // Valid when input functional unit matches BRANCH
    fu_branch_out_o.valid     = (dec_ex_i.fu == FU_BRANCH);
    fu_branch_out_o.target_pc = '0;
    fu_branch_out_o.taken     = '0;

    case (branch_uOP_e'(dec_ex_i.uOP))
      BEQ: begin
        fu_branch_out_o.target_pc = dec_ex_i.pc + imm_sext;
        fu_branch_out_o.taken     = (dec_ex_i.rs1_data == dec_ex_i.rs2_data);
      end

      BNE: begin
        fu_branch_out_o.target_pc = dec_ex_i.pc + imm_sext;
        fu_branch_out_o.taken     = (dec_ex_i.rs1_data != dec_ex_i.rs2_data);
      end

      BLT: begin
        fu_branch_out_o.target_pc = dec_ex_i.pc + imm_sext;
        fu_branch_out_o.taken     = ($signed(dec_ex_i.rs1_data) < $signed(dec_ex_i.rs2_data));
      end

      BGE: begin
        fu_branch_out_o.target_pc = dec_ex_i.pc + imm_sext;
        fu_branch_out_o.taken     = ($signed(dec_ex_i.rs1_data) >= $signed(dec_ex_i.rs2_data));
      end

      BLTU: begin
        fu_branch_out_o.target_pc = dec_ex_i.pc + imm_sext;
        fu_branch_out_o.taken     = (dec_ex_i.rs1_data < dec_ex_i.rs2_data);
      end

      BGEU: begin
        fu_branch_out_o.target_pc = dec_ex_i.pc + imm_sext;
        fu_branch_out_o.taken     = (dec_ex_i.rs1_data >= dec_ex_i.rs2_data);
      end

      JAL: begin
        fu_branch_out_o.target_pc = dec_ex_i.pc + imm_sext;
        fu_branch_out_o.taken     = 1'b1;
      end

      JALR: begin
        fu_branch_out_o.target_pc = (dec_ex_i.rs1_data + imm_sext) & ~64'b1; // JALR result must be even
        fu_branch_out_o.taken     = 1'b1;
      end
    endcase
  end

endmodule
`endif
