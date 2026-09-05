/**************************************************************************************************
* Module Name    : fu_alu
* Author         : Jacob Dudik
* Creation Date  : 08/16/2026
* Last edit Date : 08/16/2026
* Description    : Arithmetic Logic Unit (ALU) functional unit for RV64I / RV32I operations.
*                  
*                  
**************************************************************************************************/


`ifndef FU_ALU
`define FU_ALU
module fu_alu
  import core_pkg::*;
  import interface_struct_pkg::*;
  (
    // ========= Inputs ==========
    input  decode_execute_if_t dec_ex_i,

    // ========= Outputs =========
    output fu_alu_out_t        fu_alu_out_o
  );

  // ============================================
  //         Internal Signals / Types            
  // ============================================
  alu_uOP_e    alu_op;
  logic [31:0] res32;

  // ============================================
  //                 ALU Logic                   
  // ============================================
  always_comb begin
    alu_op              = alu_uOP_e'(dec_ex_i.uOP);
    fu_alu_out_o.valid  = (dec_ex_i.fu == ALU);
    fu_alu_out_o.result = '0;
    res32               = '0;

    if (dec_ex_i.is_32b) begin
      // Instructions use 32-bit data (sign-extended to 64-bits)
      case (alu_op)
        ALU_ADD:  res32 = dec_ex_i.rs1_data[31:0] + dec_ex_i.rs2_data[31:0];

        ALU_SUB:  res32 = dec_ex_i.rs1_data[31:0] - dec_ex_i.rs2_data[31:0];

        ALU_SLL:  res32 = dec_ex_i.rs1_data[31:0] << dec_ex_i.rs2_data[4:0];
        
        ALU_SRL:  res32 = dec_ex_i.rs1_data[31:0] >> dec_ex_i.rs2_data[4:0];
        
        ALU_SRA:  res32 = $signed(dec_ex_i.rs1_data[31:0]) >>> dec_ex_i.rs2_data[4:0];
        
        ALU_SLT:  res32 = ($signed(dec_ex_i.rs1_data[31:0]) < $signed(dec_ex_i.rs2_data[31:0])) ? 32'd1 : 32'd0;
        
        ALU_SLTU: res32 = (dec_ex_i.rs1_data[31:0] < dec_ex_i.rs2_data[31:0]) ? 32'd1 : 32'd0;
        
        ALU_XOR:  res32 = dec_ex_i.rs1_data[31:0] ^ dec_ex_i.rs2_data[31:0];
        
        ALU_OR:   res32 = dec_ex_i.rs1_data[31:0] | dec_ex_i.rs2_data[31:0];

        ALU_AND:  res32 = dec_ex_i.rs1_data[31:0] & dec_ex_i.rs2_data[31:0];
      endcase

      fu_alu_out_o.result = {{(64-32){res32[31]}}, res32};

    end else begin
      // Instructions use 64-bit data
      case (alu_op)
        ALU_ADD:   fu_alu_out_o.result = dec_ex_i.rs1_data + dec_ex_i.rs2_data;

        ALU_SUB:   fu_alu_out_o.result = dec_ex_i.rs1_data - dec_ex_i.rs2_data;
        
        ALU_SLL:   fu_alu_out_o.result = dec_ex_i.rs1_data << dec_ex_i.rs2_data[5:0];

        ALU_SRL:   fu_alu_out_o.result = dec_ex_i.rs1_data >> dec_ex_i.rs2_data[5:0];

        ALU_SRA:   fu_alu_out_o.result = $signed(dec_ex_i.rs1_data) >>> dec_ex_i.rs2_data[5:0];

        ALU_SLT:   fu_alu_out_o.result = ($signed(dec_ex_i.rs1_data) < $signed(dec_ex_i.rs2_data)) ? 64'd1 : 64'd0;

        ALU_SLTU:  fu_alu_out_o.result = (dec_ex_i.rs1_data < dec_ex_i.rs2_data) ? 64'd1 : 64'd0;

        ALU_XOR:   fu_alu_out_o.result = dec_ex_i.rs1_data ^ dec_ex_i.rs2_data;

        ALU_OR:    fu_alu_out_o.result = dec_ex_i.rs1_data | dec_ex_i.rs2_data;

        ALU_AND:   fu_alu_out_o.result = dec_ex_i.rs1_data & dec_ex_i.rs2_data;

        ALU_LUI:   fu_alu_out_o.result = {{32{dec_ex_i.imm[19]}}, dec_ex_i.imm, 12'b0};

        ALU_AUIPC: fu_alu_out_o.result = dec_ex_i.pc + {{32{dec_ex_i.imm[19]}}, dec_ex_i.imm, 12'b0};
      endcase
    end
  end

endmodule
`endif
