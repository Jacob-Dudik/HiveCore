/**************************************************************************************************
* Module Name    : fu_store
* Author         : Jacob Dudik
* Creation Date  : 08/16/2026
* Last edit Date : 08/16/2026
* Description    : Store Functional Unit   
**************************************************************************************************/

`ifndef FU_STORE
`define FU_STORE
module fu_store
  import core_pkg::*;
  import interface_struct_pkg::*;
  (
    // ========= Inputs ==========
    input  decode_execute_if_t dec_ex_i,

    // ========= Outputs =========
    output fu_store_out_t      fu_store_out_o
  );

  // ============================================
  //         Store Execution Logic
  // ============================================
  logic [MEM_ADDR_WIDTH-1:0] addr;
  logic [7:0]                be_mask;
  logic [2:0]                offset;

  always_comb begin
    fu_store_out_o.valid = (dec_ex_i.fu == STORE);
    
    // Calculate full address and extract offset
    addr = dec_ex_i.rs1_data + {{(64-20){dec_ex_i.imm[19]}}, dec_ex_i.imm};
    
    // Send 64-bit aligned address to memory
    fu_store_out_o.addr = {addr[MEM_ADDR_WIDTH-1:3], 3'b000};
    offset = addr[2:0];

    // Determine the unshifted byte enable mask and check alignment
    be_mask = 8'b0;
    fu_store_out_o.exception = 1'b0;

    case (lsu_uOP_e'(dec_ex_i.uOP))
      LSU_LB_SB: begin
        be_mask = 8'b00000001;
      end

      LSU_LH_SH: begin
        be_mask = 8'b00000011;
        if (addr[0] != 1'b0) fu_store_out_o.exception = 1'b1;
      end
      
      LSU_LW_SW: begin
        be_mask = 8'b00001111;
        if (addr[1:0] != 2'b00) fu_store_out_o.exception = 1'b1;
      end
      
      default: begin // LSU_LD_SD
        be_mask = 8'b11111111;
        if (addr[2:0] != 3'b000) fu_store_out_o.exception = 1'b1;
      end
    endcase

    // Shift data and byte enables to the correct lane
    fu_store_out_o.be   = be_mask << offset;
    fu_store_out_o.data = dec_ex_i.rs2_data << {offset, 3'b000}; // offset * 8
  end

endmodule
`endif
