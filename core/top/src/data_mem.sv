/**************************************************************************************************
* Module Name    : data_mem
* Author         : Jacob Dudik
* Creation Date  : 08/22/2026
* Last edit Date : 08/22/2026
* Description    : Temporary data memory for the top level. Features 1 read port and 1 write port.
**************************************************************************************************/

`ifndef DATA_MEM
`define DATA_MEM
module data_mem
  import core_pkg::*;
  #(
    // ======= Parameters ========
    parameter MEM_SIZE_BYTES = 1024 * 1024 // 1 MB default
  )
  (
    // ========= Inputs ==========
    input  logic                      clk,
    input  logic                      rst_n,

    // Read Port
    input  logic                      rd_en_i,
    input  logic [MEM_ADDR_WIDTH-1:0] rd_addr_i,
    input  logic [1:0]                rd_width_i,
    input  logic                      rd_is_unsigned_i,

    // Write Port
    input  logic                      wr_en_i,
    input  logic [MEM_ADDR_WIDTH-1:0] wr_addr_i,
    input  logic [INT_REG_WIDTH-1:0]  wr_data_i,
    input  logic [7:0]                wr_be_i,

    // ========= Outputs =========
    output logic [INT_REG_WIDTH-1:0]  rd_data_o,
    output logic                      ready_o
  );

  // ============================================
  //         Internal Signals / Memory            
  // ============================================
  // Default ready to 1 for this purely combinational/1-cycle simulation memory
  assign ready_o = 1'b1;

  // Byte-addressable memory array
  logic [7:0] mem [0:MEM_SIZE_BYTES-1];

  logic [INT_REG_WIDTH-1:0] raw_rdata;

  // ============================================
  //                 Write Port                  
  // ============================================
  always_ff @(posedge clk) begin
    if (wr_en_i) begin
      if (wr_be_i[0]) mem[{wr_addr_i[MEM_ADDR_WIDTH-1:3], 3'b000}] <= wr_data_i[7:0];
      if (wr_be_i[1]) mem[{wr_addr_i[MEM_ADDR_WIDTH-1:3], 3'b001}] <= wr_data_i[15:8];
      if (wr_be_i[2]) mem[{wr_addr_i[MEM_ADDR_WIDTH-1:3], 3'b010}] <= wr_data_i[23:16];
      if (wr_be_i[3]) mem[{wr_addr_i[MEM_ADDR_WIDTH-1:3], 3'b011}] <= wr_data_i[31:24];
      if (wr_be_i[4]) mem[{wr_addr_i[MEM_ADDR_WIDTH-1:3], 3'b100}] <= wr_data_i[39:32];
      if (wr_be_i[5]) mem[{wr_addr_i[MEM_ADDR_WIDTH-1:3], 3'b101}] <= wr_data_i[47:40];
      if (wr_be_i[6]) mem[{wr_addr_i[MEM_ADDR_WIDTH-1:3], 3'b110}] <= wr_data_i[55:48];
      if (wr_be_i[7]) mem[{wr_addr_i[MEM_ADDR_WIDTH-1:3], 3'b111}] <= wr_data_i[63:56];
    end
  end

  // ============================================
  //                 Read Port                   
  // ============================================
  logic [MEM_ADDR_WIDTH-1:0] aligned_rd_addr;
  assign aligned_rd_addr = {rd_addr_i[MEM_ADDR_WIDTH-1:3], 3'b000};

  always_comb begin
    rd_data_o = '0;
    if (rd_en_i) begin
      // Read 64 bits raw from aligned address
      rd_data_o = { mem[aligned_rd_addr+7], mem[aligned_rd_addr+6], mem[aligned_rd_addr+5], mem[aligned_rd_addr+4],
                    mem[aligned_rd_addr+3], mem[aligned_rd_addr+2], mem[aligned_rd_addr+1], mem[aligned_rd_addr] };
    end
  end

endmodule
`endif
