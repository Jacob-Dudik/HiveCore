/**************************************************************************************************
* Module Name    : hazard_unit
* Author         : Jacob Dudik
* Creation Date  : 09/05/2026
* Last edit Date : 09/05/2026
* Description    : Detects Read-After-Write (RAW) data hazards and generates forwarding 
*                  mux selects or load-use stall signals.
**************************************************************************************************/

`ifndef HAZARD_UNIT
`define HAZARD_UNIT
module hazard_unit
  import core_pkg::*;
  (
    // Decode Stage Info (Instruction currently being decoded)
    input  logic [4:0]  dec_rs1_addr_i,
    input  logic        dec_en_rs1_i,
    input  logic [4:0]  dec_rs2_addr_i,
    input  logic        dec_en_rs2_i,

    // Execute Stage Info (Instruction currently executing)
    input  logic        ex_valid_i,
    input  logic [4:0]  ex_rd_addr_i,
    input  logic        ex_en_wb_i,
    input  logic        ex_is_load_i,

    // Writeback Stage Info (Instruction currently writing back)
    input  logic        wb_valid_i,
    input  logic [4:0]  wb_rd_addr_i,
    input  logic        wb_en_wb_i,

    // Outputs for Forwarding (Mux selects)
    output logic [1:0]  forward_rs1_o, // 00: RegFile, 01: EX stage, 10: WB stage
    output logic [1:0]  forward_rs2_o, // 00: RegFile, 01: EX stage, 10: WB stage

    // Output for Stalling
    output logic        load_use_stall_o
  );

  always_comb begin
    // Default outputs
    forward_rs1_o    = 2'b00;
    forward_rs2_o    = 2'b00;
    load_use_stall_o = 1'b0;

    // ----------------------------------------------------
    //             Forwarding Logic for rs1
    // ----------------------------------------------------
    if (dec_en_rs1_i && dec_rs1_addr_i != 5'd0) begin
      // Prioritize Execute stage (most recent instruction)
      if (ex_valid_i && ex_en_wb_i && (ex_rd_addr_i == dec_rs1_addr_i)) begin
        if (ex_is_load_i) begin
          // Load-Use Hazard: EX is a load, data won't be ready until it hits WB
          load_use_stall_o = 1'b1;
        end else begin
          // ALU-Use Hazard: Data is available directly from the EX ALU output
          forward_rs1_o = 2'b01;
        end
      end 
      // Next priority is Writeback stage
      else if (wb_valid_i && wb_en_wb_i && (wb_rd_addr_i == dec_rs1_addr_i)) begin
        forward_rs1_o = 2'b10;
      end
    end

    // ----------------------------------------------------
    //              Forwarding Logic for rs2
    // ----------------------------------------------------
    if (dec_en_rs2_i && dec_rs2_addr_i != 5'd0) begin
      // Prioritize Execute stage (most recent instruction)
      if (ex_valid_i && ex_en_wb_i && (ex_rd_addr_i == dec_rs2_addr_i)) begin
        if (ex_is_load_i) begin
          // Load-Use Hazard: EX is a load, data won't be ready until it hits WB
          load_use_stall_o = 1'b1;
        end else begin
          // ALU-Use Hazard: Data is available directly from the EX ALU output
          forward_rs2_o = 2'b01;
        end
      end 
      // Next priority is Writeback stage
      else if (wb_valid_i && wb_en_wb_i && (wb_rd_addr_i == dec_rs2_addr_i)) begin
        forward_rs2_o = 2'b10;
      end
    end
  end

endmodule
`endif
