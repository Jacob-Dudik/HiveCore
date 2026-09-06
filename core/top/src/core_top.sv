/**************************************************************************************************
* Module Name    : core_top
* Author         : Jacob Dudik
* Creation Date  : 09/05/2026
* Last edit Date : 09/05/2026
* Description    : Top-level wrapper for the HiveCore in-order RISC-V processor.
*                  Instantiates and connects all pipeline stages, memory, and controllers.
**************************************************************************************************/

`ifndef CORE_TOP
`define CORE_TOP
module core_top
  import core_pkg::*;
  import interface_struct_pkg::*;
  #(
    parameter FETCH_WIDTH = 1
  )
  (
    input  logic clk,
    input  logic rst_n,
    
    // External interrupts/resets
    input  logic ext_flush_i
  );

  // =========================================================================
  //                       Inter-Stage Signals
  // =========================================================================

  // Controller -> Stages
  logic                      fetch_flush;
  logic                      decode_flush;
  logic                      execute_flush;
  logic                      redirect_pc_valid;
  logic [MEM_ADDR_WIDTH-1:0] redirect_pc;

  // Fetch -> I-Mem
  logic [MEM_ADDR_WIDTH-1:0]               imem_req_addr;
  logic                                    imem_req_valid;
  logic [FETCH_WIDTH-1:0][INSTR_WIDTH-1:0] imem_rdata;
  logic                                    imem_ready;

  // Fetch -> Decode (IF/ID Pipeline Register)
  logic [FETCH_WIDTH-1:0]                      if_id_valid;
  logic [FETCH_WIDTH-1:0][INSTR_WIDTH-1:0]     if_id_instr;
  logic [FETCH_WIDTH-1:0][MEM_ADDR_WIDTH-1:0]  if_id_pc;

  // Decode -> Execute (ID/EX Pipeline Register)
  logic [FETCH_WIDTH-1:0]    id_ex_valid;
  decode_execute_if_t        id_ex_data [FETCH_WIDTH-1:0];

  // Execute -> D-Mem
  logic                      dmem_req_valid;
  logic                      dmem_is_store;
  logic [MEM_ADDR_WIDTH-1:0] dmem_addr;
  logic [INT_REG_WIDTH-1:0]  dmem_wdata;
  logic [7:0]                dmem_be;
  logic [INT_REG_WIDTH-1:0]  dmem_rdata;
  logic                      dmem_ready;

  // Execute -> Control / Bypass
  logic                      ex_branch_taken;
  logic [MEM_ADDR_WIDTH-1:0] ex_target_pc;
  
  logic                      ex_fwd_valid;
  logic [4:0]                ex_fwd_rd_addr;
  logic                      ex_fwd_en_wb;
  logic                      ex_fwd_is_load;
  logic [INT_REG_WIDTH-1:0]  ex_fwd_data;

  // Execute -> Writeback (EX/WB Pipeline Register)
  logic                      ex_wb_valid;
  execute_wb_if_t            ex_wb_data;

  // Writeback -> Decode
  logic                      rf_wr_valid;
  logic [4:0]                rf_wr_addr;
  logic [INT_REG_WIDTH-1:0]  rf_wr_data;

  // Writeback -> Control
  logic                      wb_exception;

  // Ready / Valid Handshaking
  logic fetch_ready, decode_ready, execute_ready, writeback_ready;

  // =========================================================================
  //                       Module Instantiations
  // =========================================================================

  // ----------------------------------------------------
  //                  Core Controller
  // ----------------------------------------------------
  ctrl_unit u_ctrl_unit (
    .clk                  (clk),
    .rst_n                (rst_n),
    .global_flush_i       (ext_flush_i),

    .ex_pc_i              (id_ex_data[0].pc),
    .ex_branch_taken_i    (ex_branch_taken),
    .ex_target_pc_i       (ex_target_pc),

    // Static not-taken prediction (TODO: fix when branch predictor finished)
    .pred_branch_taken_i  (1'b0),
    .pred_target_pc_i     ('0),

    .wb_exception_i       (wb_exception),

    .fetch_flush_o        (fetch_flush),
    .decode_flush_o       (decode_flush),
    .execute_flush_o      (execute_flush),

    .redirect_pc_valid_o  (redirect_pc_valid),
    .redirect_pc_o        (redirect_pc)
  );

  // ----------------------------------------------------
  //                Instruction Memory
  // ----------------------------------------------------
  instr_mem #(
    .FETCH_WIDTH      (FETCH_WIDTH)
  ) u_instr_mem (
    .clk              (clk),
    .rst_n            (rst_n),
    .imem_req_addr_i  (imem_req_addr),
    .imem_req_valid_i (imem_req_valid),
    .imem_rdata_o     (imem_rdata),
    .imem_ready_o     (imem_ready)
  );

  // ----------------------------------------------------
  //                  Fetch Stage
  // ----------------------------------------------------
  fetch #(
    .FETCH_WIDTH      (FETCH_WIDTH)
  ) u_fetch (
    .clk              (clk),
    .rst_n            (rst_n),
    
    .flush_i          (fetch_flush),
    .ready_i          (decode_ready),

    .branch_taken_i   (redirect_pc_valid),
    .target_pc_i      (redirect_pc),

    .imem_req_addr_o  (imem_req_addr),
    .imem_req_valid_o (imem_req_valid),
    .imem_rdata_i     (imem_rdata),
    .imem_ready_i     (imem_ready),

    .instr_valid_o    (if_id_valid),
    .instr_o          (if_id_instr),
    .instr_pc_o       (if_id_pc)
  );

  // ----------------------------------------------------
  //                  Decode Stage
  // ----------------------------------------------------
  decode u_decode (
    .clk               (clk),
    .rst_n             (rst_n),
    
    .flush             (decode_flush),
    .ready_i           (execute_ready),
    .ready_o           (decode_ready),
    
    .instr_valid_i     (if_id_valid),
    .instr_i           (if_id_instr),
    .instr_pc_i        (if_id_pc),

    // Bypass forwarding from Execute
    .ex_valid_i        (ex_fwd_valid),
    .ex_rd_addr_i      (ex_fwd_rd_addr),
    .ex_en_wb_i        (ex_fwd_en_wb),
    .ex_is_load_i      (ex_fwd_is_load),
    .ex_fwd_data_i     (ex_fwd_data),

    // Bypass forwarding from Writeback
    .wb_valid_i        (rf_wr_valid),
    .wb_rd_addr_i      (rf_wr_addr),
    .wb_en_wb_i        (rf_wr_valid),
    .wb_fwd_data_i     (rf_wr_data),

    // Architectural commit to Register File
    .wb_rf_we_i        (rf_wr_valid),
    .wb_rf_waddr_i     (rf_wr_addr),
    .wb_rf_wdata_i     (rf_wr_data),

    .instr_valid_o     (id_ex_valid),
    .DE_if_o           (id_ex_data)
  );

  // ----------------------------------------------------
  //                  Execute Stage
  // ----------------------------------------------------
  execute u_execute (
    .clk               (clk),
    .rst_n             (rst_n),
    
    .flush             (execute_flush),
    .ready_i           (writeback_ready),
    .ready_o           (execute_ready),
    
    // Inputs from Decode
    .valid_i           (id_ex_valid[0]),
    .dec_ex_i          (id_ex_data[0]),

    // Data Memory interface
    .mem_rdata_i       (dmem_rdata),
    .mem_ready_i       (dmem_ready),
    .mem_req_valid_o   (dmem_req_valid),
    .mem_is_store_o    (dmem_is_store),
    .mem_addr_o        (dmem_addr),
    .mem_wdata_o       (dmem_wdata),
    .mem_be_o          (dmem_be),

    // Fast-branch resolution (to Controller)
    .branch_taken_o    (ex_branch_taken),
    .target_pc_o       (ex_target_pc),

    // Combinational forwarding data (to Decode)
    .ex_fwd_valid_o    (ex_fwd_valid),
    .ex_fwd_rd_addr_o  (ex_fwd_rd_addr),
    .ex_fwd_en_wb_o    (ex_fwd_en_wb),
    .ex_fwd_is_load_o  (ex_fwd_is_load),
    .ex_fwd_data_o     (ex_fwd_data),

    // Registered output to Writeback
    .valid_o           (ex_wb_valid),
    .ex_wb_o           (ex_wb_data)
  );

  // ----------------------------------------------------
  //                    Data Memory
  // ----------------------------------------------------
  data_mem u_data_mem (
    .clk        (clk),
    .rst_n      (rst_n),
    
    .rd_en_i    (dmem_req_valid & ~dmem_is_store),
    .rd_addr_i  (dmem_addr),
    
    .wr_en_i    (dmem_req_valid & dmem_is_store),
    .wr_addr_i  (dmem_addr),
    .wr_data_i  (dmem_wdata),
    .wr_be_i    (dmem_be),
    
    .rd_data_o  (dmem_rdata),
    .ready_o    (dmem_ready)
  );

  // ----------------------------------------------------
  //                  Writeback Stage
  // ----------------------------------------------------
  writeback u_writeback (
    .valid_i        (ex_wb_valid),
    .ex_wb_i        (ex_wb_data),
    .ready_o        (writeback_ready),

    // Outputs directly to the RegFile in Decode, and bypassed back to Decode muxes
    .rf_wr_valid_o  (rf_wr_valid),
    .rf_wr_addr_o   (rf_wr_addr),
    .rf_wr_data_o   (rf_wr_data),

    // NOTE: branch_taken_o and target_pc_o are ignored here until OoO
    .branch_taken_o (),
    .target_pc_o    (),

    .exception_o    (wb_exception)
  );

endmodule
`endif
