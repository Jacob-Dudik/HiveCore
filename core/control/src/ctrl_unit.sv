/**************************************************************************************************
* Module Name    : ctrl_unit
* Author         : Jacob Dudik
* Creation Date  : 09/05/2026
* Last edit Date : 09/05/2026
* Description    : Detects Read-After-Write (RAW) data hazards and generates forwarding 
* Description    : Global pipeline controller. Resolves stalls, flushes, and branch mispredictions.
**************************************************************************************************/

`ifndef CTRL_UNIT
`define CTRL_UNIT
module ctrl_unit
  import core_pkg::*;
  (
    input  logic                      clk,
    input  logic                      rst_n,
    input  logic                      global_flush_i,

    // Hazard inputs from Decode
    input  logic                      dec_load_use_stall_i,

    // Branch / Memory inputs from Execute
    input  logic                      ex_mem_stall_i,
    input  logic [MEM_ADDR_WIDTH-1:0] ex_pc_i,           // PC of the instruction currently in Execute
    input  logic                      ex_branch_taken_i, // Resolved branch outcome
    input  logic [MEM_ADDR_WIDTH-1:0] ex_target_pc_i,    // Resolved branch target

    // Branch Prediction (piped down from Fetch/Decode to match the instruction in Execute)
    input  logic                      pred_branch_taken_i,
    input  logic [MEM_ADDR_WIDTH-1:0] pred_target_pc_i,

    // Exception inputs from Writeback
    input  logic                      wb_exception_i,

    // ----------------------------------------------------
    //            Pipeline Control Outputs
    // ----------------------------------------------------
    output logic                      fetch_stall_o,
    output logic                      fetch_flush_o,
    
    output logic                      decode_stall_o,
    output logic                      decode_flush_o,
    
    output logic                      execute_stall_o,
    output logic                      execute_flush_o,

    // Fetch PC Override Interface
    output logic                      redirect_pc_valid_o,
    output logic [MEM_ADDR_WIDTH-1:0] redirect_pc_o
  );

  logic branch_mispredict;

  always_comb begin
    // Determine if the branch was mispredicted
    branch_mispredict = 1'b0;
    if (ex_branch_taken_i != pred_branch_taken_i) begin
      branch_mispredict = 1'b1;
    end else if (ex_branch_taken_i && (ex_target_pc_i != pred_target_pc_i)) begin
      branch_mispredict = 1'b1;
    end

    // Default Control Signals
    fetch_stall_o       = 1'b0;
    fetch_flush_o       = 1'b0;
    
    decode_stall_o      = 1'b0;
    decode_flush_o      = 1'b0;
    
    execute_stall_o     = 1'b0;
    execute_flush_o     = 1'b0;
    
    redirect_pc_valid_o = 1'b0;
    redirect_pc_o       = '0;

    // ============================================
    //          Exception / Global Flush
    // ============================================
    if (global_flush_i || wb_exception_i) begin
      fetch_flush_o   = 1'b1;
      decode_flush_o  = 1'b1;
      execute_flush_o = 1'b1;
      
      // If it's an exception, redirect PC to a trap vector.
      if (wb_exception_i) begin
        redirect_pc_valid_o = 1'b1;
        redirect_pc_o       = 64'h0000_0000_0000_0000; // TODO: Jump to MTVEC
      end
    end
    
    // ============================================
    //            Branch Misprediction
    // ============================================
    else if (branch_mispredict) begin
      // If mispredicted, flush the instructions that were fetchedbehind the branch
      fetch_flush_o  = 1'b1;
      decode_flush_o = 1'b1;
      
      // Tell Fetch to jump to the correct PC
      redirect_pc_valid_o = 1'b1;
      if (ex_branch_taken_i) begin
        // Predicted not-taken (or wrong target), but it was taken; jump to target
        redirect_pc_o = ex_target_pc_i;
      end else begin
        // Predicted taken, but it was actually not taken; Jump to PC + 4
        redirect_pc_o = ex_pc_i + 4;
      end
    end

    // ============================================
    //                Memory Stall
    // ============================================
    else if (ex_mem_stall_i) begin
      // Memory is busy; freeze the entire front-end of the pipeline
      fetch_stall_o   = 1'b1;
      decode_stall_o  = 1'b1;
      execute_stall_o = 1'b1;
    end
    
    // ============================================
    //            Load-Use Data Hazard
    // ============================================
    else if (dec_load_use_stall_i) begin
      // Decode needs a register that Execute is currently loading from memory
      // Freeze Fetch and Decode; allow Execute to proceed so the load finishes
      fetch_stall_o  = 1'b1;
      decode_stall_o = 1'b1;
      
      // Because Decode is stalled, it won't send valid data to Execute next cycle
      // Flush the Execute stage input register
      execute_flush_o = 1'b1;
    end
  end

endmodule
`endif
