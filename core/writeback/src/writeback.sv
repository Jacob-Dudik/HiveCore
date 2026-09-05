/**************************************************************************************************
* Module Name    : writeback
* Author         : Jacob Dudik
* Creation Date  : 09/05/2026
* Last edit Date : 09/05/2026
* Description    : Pipeline writeback stage. Commits results to the register file and 
*                  routes branch/exception signals to the global controller.
**************************************************************************************************/

`ifndef WRITEBACK
`define WRITEBACK
module writeback
  import core_pkg::*;
  import interface_struct_pkg::*;
  (
    // Inputs from Execute Stage
    input  logic                                valid_i,
    input  execute_wb_if_t                      ex_wb_i,

    // Register File Write Interface
    output logic                                rf_wr_valid_o,
    output logic [INT_REG_ADDR_WIDTH-1:0]       rf_wr_addr_o,
    output logic [INT_REG_WIDTH-1:0]            rf_wr_data_o,

    // Control Unit / Fetch Interface
    // NOTE: These branch signals will be used for future OoO
    output logic                                branch_taken_o,
    output logic [MEM_ADDR_WIDTH-1:0]           target_pc_o,

    // Trap / Exception Interface
    output logic                                exception_o
  );

  always_comb begin
    // Default outputs
    rf_wr_valid_o = 1'b0;
    rf_wr_addr_o  = '0;
    rf_wr_data_o  = '0;

    branch_taken_o = 1'b0;
    target_pc_o    = '0;
    
    exception_o    = 1'b0;

    // Only process valid instructions
    if (valid_i && ex_wb_i.valid) begin
      
      // ============================================
      //         Register File Write Logic
      // ============================================
      // RISC-V Rule: Register 0 (x0) is hardwired to 0. 
      // We enforce this by simply disabling the write enable if rd_addr == 0.
      if (ex_wb_i.en_wb && ex_wb_i.rd_addr != 5'd0) begin
        rf_wr_valid_o = 1'b1;
        rf_wr_addr_o  = ex_wb_i.rd_addr;
        rf_wr_data_o  = ex_wb_i.result;
      end

      // ============================================
      //         Branch & Control Flow Logic
      // ============================================
      // If a branch was taken or a jump occurred, flag the controller 
      // to flush the pipeline and redirect the Fetch stage PC.
      if (ex_wb_i.branch_taken) begin
        branch_taken_o = 1'b1;
        target_pc_o    = ex_wb_i.next_pc;
      end

      // ============================================
      //         Exception / Trap Logic
      // ============================================
      if (ex_wb_i.exception) begin
        // TODO: In the future, this will trigger the CSR (Control and Status Register)
        // module to take a machine-mode trap, save the PC to MEPC, and jump to MTVEC.
        exception_o = 1'b1;
      end
      
    end
  end

endmodule
`endif
