/**************************************************************************************************
* Module Name    : instr_mem
* Author         : Jacob Dudik
* Creation Date  : 09/05/2026
* Last edit Date : 09/05/2026
* Description    : Instruction memory. Read-only combinational memory.
**************************************************************************************************/

`ifndef INSTR_MEM
`define INSTR_MEM
module instr_mem
  import core_pkg::*;
  #(
    parameter MEM_SIZE_BYTES = 4096,
    parameter FETCH_WIDTH    = 1
  )
  (
    input  logic                                          clk,
    input  logic                                          rst_n,

    // Instruction Memory Interface (from Fetch)
    input  logic [MEM_ADDR_WIDTH-1:0]                     imem_req_addr_i,
    input  logic                                          imem_req_valid_i,
    output logic [FETCH_WIDTH-1:0][INSTR_WIDTH-1:0]       imem_rdata_o,
    output logic                                          imem_ready_o
  );

  // Default ready to 1 for this purely combinational/1-cycle simulation memory
  assign imem_ready_o = 1'b1;

  // Byte-addressable memory array
  logic [7:0] mem [0:MEM_SIZE_BYTES-1];

  // TODO: Add $readmemh to initialize the instruction memory with a compiled RISC-V binary!
  /*
  initial begin
    $readmemh("firmware.hex", mem);
  end
  */

  // ============================================
  //                 Read Port                   
  // ============================================
  always_comb begin
    imem_rdata_o = '0;
    
    if (imem_req_valid_i) begin
      for (int i = 0; i < FETCH_WIDTH; i++) begin
        // RISC-V instructions are 32-bit (4 bytes)
        // Calculating address for the specific fetch slot
        logic [MEM_ADDR_WIDTH-1:0] addr = imem_req_addr_i + (i * 4);
        
        // Read 32 bits (4 bytes) raw, Little-endian mapping
        imem_rdata_o[i] = { mem[addr+3], mem[addr+2], mem[addr+1], mem[addr] };
      end
    end
  end

endmodule
`endif
