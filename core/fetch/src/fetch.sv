/**************************************************************************************************
* Module Name    : fetch
* Author         : Jacob Dudik
* Creation Date  : 09/05/2026
* Last edit Date : 09/05/2026
* Description    : Instruction fetch stage. Maintains PC and fetches from instruction memory.
**************************************************************************************************/

`ifndef FETCH
`define FETCH
module fetch
  import core_pkg::*;
  #(
    parameter FETCH_WIDTH = 1,
    parameter RESET_PC    = 64'h0000_0000_0000_0000
  )
  (
    input  logic                                        clk,
    input  logic                                        rst_n,

    // Pipeline Control
    input  logic                                        flush_i,
    input  logic                                        stall_i,

    // Branch / Jump interface
    input  logic                                        branch_taken_i,
    input  logic [MEM_ADDR_WIDTH-1:0]                   target_pc_i,

    // Instruction Memory Interface
    output logic [MEM_ADDR_WIDTH-1:0]                   imem_req_addr_o,
    output logic                                        imem_req_valid_o,
    input  logic [FETCH_WIDTH-1:0][INSTR_WIDTH-1:0]     imem_rdata_i,
    input  logic                                        imem_ready_i,

    // IF/ID Pipeline Register Outputs (to Decode)
    output logic [FETCH_WIDTH-1:0]                      instr_valid_o,
    output logic [FETCH_WIDTH-1:0][INSTR_WIDTH-1:0]     instr_o,
    output logic [FETCH_WIDTH-1:0][MEM_ADDR_WIDTH-1:0]  instr_pc_o
  );

  // ============================================
  //             Program Counter Logic           
  // ============================================
  logic [MEM_ADDR_WIDTH-1:0] pc_q, pc_d;

  always_comb begin
    pc_d = pc_q;

    // Highest priority: branch taken / jump
    if (branch_taken_i) begin
      pc_d = target_pc_i;
    end 
    
    // Normal PC increment if not stalled, not flushed, and memory is ready
    else if (!stall_i && imem_ready_i && !flush_i) begin
      pc_d = pc_q + (FETCH_WIDTH * 4);
    end
  end

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      pc_q <= RESET_PC;
    end else begin
      pc_q <= pc_d;
    end
  end

  // ============================================
  //          Memory Request Interface           
  // ============================================
  // Always request memory unless we are in reset
  assign imem_req_addr_o  = pc_q;
  assign imem_req_valid_o = 1'b1;

  // ============================================
  //             IF/ID Stage Registers           
  // ============================================
  always_ff @(posedge clk) begin
    if (!rst_n || flush_i) begin
      instr_valid_o <= '0;
      instr_o       <= '0;
      instr_pc_o    <= '0;

    end else if (!stall_i) begin
      // Instruction memory is ready for read
      if (imem_ready_i) begin
        // TODO: adjust imem to support multiple reads
        instr_valid_o <= {FETCH_WIDTH{1'b1}};
        instr_o       <= imem_rdata_i;

        // Send PC down the pipe
        for (int i = 0; i < FETCH_WIDTH; i++) begin
          instr_pc_o[i] <= pc_q + (i * 4);
        end
      end else begin
        // If memory isn't ready but we aren't stalling, insert a pipeline bubble
        instr_valid_o <= '0;
      end
    end
  end

endmodule
`endif
