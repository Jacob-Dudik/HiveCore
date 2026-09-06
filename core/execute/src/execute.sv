/**************************************************************************************************
* Module Name    : execute
* Author         : Jacob Dudik
* Creation Date  : 08/16/2026
* Last edit Date : 08/16/2026
* Description    : Execute stage module that instantiates FUs and routes data.   
**************************************************************************************************/

`ifndef EXECUTE
`define EXECUTE
module execute
  import core_pkg::*;
  import interface_struct_pkg::*;
  (
    // ========= Inputs ==========
    input  logic                      clk,
    input  logic                      rst_n,

    input  logic                      flush,
    input  logic                      ready_i,
    output logic                      ready_o,
    input  logic                      valid_i,
    input  decode_execute_if_t        dec_ex_i,

    // Memory interface inputs
    input  logic [INT_REG_WIDTH-1:0]  mem_rdata_i,
    input  logic                      mem_ready_i,

    // ========= Outputs =========
    output logic                      valid_o,
    output execute_wb_if_t            ex_wb_o,

    // Memory interface outputs
    output logic                      mem_req_valid_o,
    output logic                      mem_is_store_o,
    output logic [MEM_ADDR_WIDTH-1:0] mem_addr_o,
    output logic [INT_REG_WIDTH-1:0]  mem_wdata_o,
    output logic [7:0]                mem_be_o,

    // Early branch resolution
    output logic                      branch_taken_o,
    output logic [MEM_ADDR_WIDTH-1:0] target_pc_o,

    // Send forwarding data (to Decode)
    output logic                      ex_fwd_valid_o,
    output logic [4:0]                ex_fwd_rd_addr_o,
    output logic                      ex_fwd_en_wb_o,
    output logic                      ex_fwd_is_load_o,
    output logic [INT_REG_WIDTH-1:0]  ex_fwd_data_o
  );

  // ============================================
  //         Internal Signals / Modules            
  // ============================================
  // Stage Output Data
  execute_wb_if_t ex_wb_d;

  // Functional Unit Outputs
  fu_alu_out_t    alu_out;
  fu_branch_out_t branch_out;
  fu_load_out_t   load_out;
  fu_store_out_t  store_out;

  // Instantiate FUs
  fu_alu u_fu_alu (
    .dec_ex_i        (dec_ex_i),
    .fu_alu_out_o    (alu_out)
  );

  fu_branch u_fu_branch (
    .dec_ex_i        (dec_ex_i),
    .fu_branch_out_o (branch_out)
  );

  fu_load u_fu_load (
    .dec_ex_i        (dec_ex_i),
    .mem_rdata_i     (mem_rdata_i),
    .fu_load_out_o   (load_out)
  );

  fu_store u_fu_store (
    .dec_ex_i        (dec_ex_i),
    .fu_store_out_o  (store_out)
  );

  // ============================================
  //   Multiplex FU outputs to Writeback / Memory
  // ============================================

  // Route memory requests to the top-level memory ports (suppress if exception)
  assign mem_req_valid_o = ((load_out.valid & ~load_out.exception) | (store_out.valid & ~store_out.exception)) & valid_i;
  assign mem_is_store_o  = store_out.valid;
  assign mem_addr_o      = store_out.valid ? store_out.addr : load_out.addr;
  assign mem_wdata_o     = store_out.data;
  assign mem_be_o        = store_out.be;

  // Execute is ready if we are not stalled by memory, AND the next stage is ready
  logic mem_stall;
  assign mem_stall = mem_req_valid_o & ~mem_ready_i;
  assign ready_o = ~mem_stall & ready_i;

  // Early branch resolution (combinational) to minimize branch penalty
  // Only valid if the current execution stage is valid and it's actually a branch instruction!
  assign branch_taken_o = branch_out.valid & branch_out.taken & valid_i;
  assign target_pc_o    = branch_out.target_pc;

  // Forwarding Outputs
  assign ex_fwd_valid_o   = valid_i;
  assign ex_fwd_is_load_o = (dec_ex_i.fu == FU_LOAD);
  assign ex_fwd_rd_addr_o = ex_wb_d.rd_addr;
  assign ex_fwd_en_wb_o   = ex_wb_d.en_wb;
  assign ex_fwd_data_o    = ex_wb_d.result;

  always_comb begin
    // Default assignments
    ex_wb_d = '0;

    // Pass through writeback control signals
    ex_wb_d.rd_addr = dec_ex_i.rd_addr;
    ex_wb_d.en_wb   = dec_ex_i.en_wb;

    // Select the correct result from the FUs
    case (dec_ex_i.fu)
      FU_ALU: begin
        ex_wb_d.valid     = alu_out.valid;
        ex_wb_d.result    = alu_out.result;
        ex_wb_d.exception = 1'b0;
      end

      FU_BRANCH: begin
        ex_wb_d.valid        = branch_out.valid;
        ex_wb_d.result       = dec_ex_i.pc + 4; // Return address for jumps
        ex_wb_d.next_pc      = branch_out.target_pc;
        ex_wb_d.branch_taken = branch_out.taken;
        ex_wb_d.exception    = 1'b0;
      end
      
      FU_LOAD: begin
        // The result of a load comes from the memory return data, formatted by fu_load
        ex_wb_d.valid     = load_out.valid;
        ex_wb_d.result    = load_out.formatted_data;
        ex_wb_d.exception = load_out.exception;
      end
      
      FU_STORE: begin
        ex_wb_d.valid     = store_out.valid;
        ex_wb_d.exception = store_out.exception;
      end
    endcase
  end

  // ============================================
  //             Output Register Stage         
  // ============================================
  
  // Only advance the pipeline register if we are ready (which includes ready_i from next stage)
  always_ff @(posedge clk) begin
    if (!rst_n || flush) begin
      valid_o <= '0;
      ex_wb_o <= '0;
    end else if (ready_o) begin
      valid_o <= valid_i && !branch_out.taken && !ex_wb_d.exception;
      ex_wb_o <= ex_wb_d;
      
      if (valid_i) begin
          $display("Time %0t: EXECUTING PC: %x, FU: %x, uOP: %x, RS1: %x, RS2: %x, IMM: %x", 
                   $time, dec_ex_i.pc, dec_ex_i.fu, dec_ex_i.uOP, dec_ex_i.rs1_data, dec_ex_i.rs2_data, dec_ex_i.imm);
          $display("          => Result: %x, rd: %d, en_wb: %d", ex_wb_d.result, ex_wb_d.rd_addr, ex_wb_d.en_wb);
      end
    end
  end

endmodule
`endif
