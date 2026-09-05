/**************************************************************************************************
* Module Name    : fu_load
* Author         : Jacob Dudik
* Creation Date  : 08/16/2026
* Last edit Date : 08/16/2026
* Description    : Load Functional Unit
**************************************************************************************************/

`ifndef FU_LOAD
`define FU_LOAD
module fu_load
  import core_pkg::*;
  import interface_struct_pkg::*;
  (
    // ========= Inputs ==========
    input  decode_execute_if_t       dec_ex_i,
    input  logic [INT_REG_WIDTH-1:0] mem_rdata_i,

    // ========= Outputs =========
    output fu_load_out_t             fu_load_out_o
  );

  // ============================================
  //         Load Execution Logic
  // ============================================
  logic [MEM_ADDR_WIDTH-1:0] addr;
  logic [2:0]                offset;
  logic [INT_REG_WIDTH-1:0]  shifted_data;

  always_comb begin
    // Match FU
    fu_load_out_o.valid = (dec_ex_i.fu == FU_LOAD);
    
    // Calculate address and extract offset
    addr = dec_ex_i.rs1_data + {{(64-20){dec_ex_i.imm[19]}}, dec_ex_i.imm};
    
    // Send 64-bit aligned address to memory
    fu_load_out_o.addr = {addr[MEM_ADDR_WIDTH-1:3], 3'b000};
    offset = addr[2:0];
    
    // Shift the raw 64-bit bus data so the target bytes are at the bottom
    shifted_data = mem_rdata_i >> {offset, 3'b000}; // offset * 8

    fu_load_out_o.exception = 1'b0;

    // Mask and sign-extend based on instruction, and check alignment
    case (lsu_uOP_e'(dec_ex_i.uOP))
      LSU_LB_SB: begin
        fu_load_out_o.formatted_data = { {(INT_REG_WIDTH-8){shifted_data[7]}}, shifted_data[7:0] };
      end
      
      LSU_LH_SH: begin
        fu_load_out_o.formatted_data = { {(INT_REG_WIDTH-16){shifted_data[15]}}, shifted_data[15:0] };
        if (addr[0] != 1'b0) fu_load_out_o.exception = 1'b1;
      end

      LSU_LW_SW: begin
        fu_load_out_o.formatted_data = { {(INT_REG_WIDTH-32){shifted_data[31]}}, shifted_data[31:0] };
        if (addr[1:0] != 2'b00) fu_load_out_o.exception = 1'b1;
      end
      
      LSU_LD_SD: begin
        fu_load_out_o.formatted_data = shifted_data;
        if (addr[2:0] != 3'b000) fu_load_out_o.exception = 1'b1;
      end
      
      LSU_LBU: begin
        fu_load_out_o.formatted_data = { {(INT_REG_WIDTH-8){1'b0}}, shifted_data[7:0] };
      end
      
      LSU_LHU: begin
        fu_load_out_o.formatted_data = { {(INT_REG_WIDTH-16){1'b0}}, shifted_data[15:0] };
        if (addr[0] != 1'b0) fu_load_out_o.exception = 1'b1;
      end
      
      LSU_LWU: begin
        fu_load_out_o.formatted_data = { {(INT_REG_WIDTH-32){1'b0}}, shifted_data[31:0] };
        if (addr[1:0] != 2'b00) fu_load_out_o.exception = 1'b1;
      end
      
      default: begin
        fu_load_out_o.formatted_data = shifted_data; // Default LD
      end
    endcase
  end

endmodule
`endif
