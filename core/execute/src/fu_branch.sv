/**************************************************************************************************
* Module Name    : fu_branch
* Author         : Jacob Dudik
* Creation Date  : 09/05/2026
* Last edit Date : 09/05/2026
* Description    : Branch functional unit. Calculates branch outcomes and target PCs.
**************************************************************************************************/

`ifndef FU_BRANCH
`define FU_BRANCH
module fu_branch
  import core_pkg::*;
  import interface_struct_pkg::*;
  (
    input  decode_execute_if_t dec_ex_i,
    output fu_branch_out_t     fu_branch_out_o
  );

  // ============================================
  //         Internal Signals
  // ============================================
  logic [63:0] imm_sext;
  logic        branch_taken;
  
  // ============================================
  //         Branch Execution Logic
  // ============================================
  always_comb begin
    // Default valid checking
    fu_branch_out_o.valid     = (dec_ex_i.fu == FU_BRANCH);
    fu_branch_out_o.target_pc = '0;
    branch_taken              = 1'b0;

    // Immediate sign extension for branch target calculation
    imm_sext = { {(64-20){dec_ex_i.imm[19]}}, dec_ex_i.imm };

    case (branch_uOP_e'(dec_ex_i.uOP))
      BEQ: begin
        fu_branch_out_o.target_pc = dec_ex_i.pc + imm_sext;
        branch_taken              = (dec_ex_i.rs1_data == dec_ex_i.rs2_data);
      end

      BNE: begin
        fu_branch_out_o.target_pc = dec_ex_i.pc + imm_sext;
        branch_taken              = (dec_ex_i.rs1_data != dec_ex_i.rs2_data);
      end

      BLT: begin
        fu_branch_out_o.target_pc = dec_ex_i.pc + imm_sext;
        branch_taken              = ($signed(dec_ex_i.rs1_data) < $signed(dec_ex_i.rs2_data));
      end

      BGE: begin
        fu_branch_out_o.target_pc = dec_ex_i.pc + imm_sext;
        branch_taken              = ($signed(dec_ex_i.rs1_data) >= $signed(dec_ex_i.rs2_data));
      end

      BLTU: begin
        fu_branch_out_o.target_pc = dec_ex_i.pc + imm_sext;
        branch_taken              = (dec_ex_i.rs1_data < dec_ex_i.rs2_data);
      end

      BGEU: begin
        fu_branch_out_o.target_pc = dec_ex_i.pc + imm_sext;
        branch_taken              = (dec_ex_i.rs1_data >= dec_ex_i.rs2_data);
      end

      BR_JAL: begin
        fu_branch_out_o.target_pc = dec_ex_i.pc + imm_sext;
        branch_taken              = 1'b1;
      end

      BR_JALR: begin
        fu_branch_out_o.target_pc = (dec_ex_i.rs1_data + imm_sext) & ~64'b1; // JALR result must be even
        branch_taken              = 1'b1;
      end
    endcase
    
    // Assert taken if this was a valid and taken branch
    fu_branch_out_o.taken = branch_taken & fu_branch_out_o.valid;
  end

endmodule
`endif
