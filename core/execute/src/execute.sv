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
    input  logic                      stall_i,
    input  logic                      valid_i,
    input  decode_execute_if_t        dec_ex_i,

    // Memory interface inputs
    input  logic [INT_REG_WIDTH-1:0]  mem_rdata_i,
    input  logic                      mem_ready_i,

    // ========= Outputs =========
    output logic                      valid_o,
    output logic                      mem_stall_o,
    output execute_wb_if_t            ex_wb_o,

    // Memory interface outputs
    output logic                      mem_req_valid_o,
    output logic                      mem_is_store_o,
    output logic [MEM_ADDR_WIDTH-1:0] mem_addr_o,
    output logic [INT_REG_WIDTH-1:0]  mem_wdata_o,
    output logic [7:0]                mem_be_o,

    // Early branch resolution
    output logic                      branch_taken_o,
    output logic [MEM_ADDR_WIDTH-1:0] target_pc_o
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

  // Output stall request if we have a valid memory request but memory is not ready
  assign mem_stall_o = mem_req_valid_o & ~mem_ready_i;

  // Early branch resolution (combinational) to minimize branch penalty
  // Only valid if the current execution stage is valid and it's actually a branch instruction!
  assign branch_taken_o = branch_out.valid & branch_out.taken & valid_i;
  assign target_pc_o    = branch_out.target_pc;

  always_comb begin
    // Default assignments
    ex_wb_d = '0;

    // Pass through writeback control signals
    ex_wb_d.rd_addr = dec_ex_i.rd_addr;
    ex_wb_d.en_wb   = dec_ex_i.en_wb;

    // Select the correct result from the FUs
    case (dec_ex_i.fu)
      ALU: begin
        ex_wb_d.valid     = alu_out.valid;
        ex_wb_d.result    = alu_out.result;
        ex_wb_d.exception = 1'b0;
      end

      BRANCH: begin
        ex_wb_d.valid        = branch_out.valid;
        ex_wb_d.result       = dec_ex_i.pc + 4; // Return address for jumps
        ex_wb_d.next_pc      = branch_out.target_pc;
        ex_wb_d.branch_taken = branch_out.taken;
        ex_wb_d.exception    = 1'b0;
      end
      
      LOAD: begin
        // The result of a load comes from the memory return data, formatted by fu_load
        ex_wb_d.valid     = load_out.valid;
        ex_wb_d.result    = load_out.formatted_data;
        ex_wb_d.exception = load_out.exception;
      end
      
      STORE: begin
        ex_wb_d.valid     = store_out.valid;
        ex_wb_d.exception = store_out.exception;
      end
    endcase
  end

  // ============================================
  //             Output Register Stage         
  // ============================================
  
  // Always pass along valid unless a stall or flush occurs
  always_ff @(posedge clk) begin
    if (!rst_n || flush || stall_i) begin
      valid_o <= '0;
    end else begin
      valid_o <= valid_i;
    end
  end

  // Pass data along when the new instruction is valid, otherwise clock gate
  always_ff @(posedge clk) begin
    if (!stall_i) begin
      ex_wb_o <= valid_i ? ex_wb_d : ex_wb_o; 
    end
  end

endmodule
`endif
