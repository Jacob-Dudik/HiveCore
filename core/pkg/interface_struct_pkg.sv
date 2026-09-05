/**************************************************************************************************
* Module Name    : interface_struct_pkg
* Author         : Jacob Dudik
* Creation Date  : 09/05/2026
* Last edit Date : 09/05/2026
* Description    : Package that defines interfaces structures for both pipeline stages and function
*                  units. Not using native SystemVerilog interfaces due to tool issues and clunkiness.
**************************************************************************************************/

`ifndef INTERFACE_STRUCT_PKG
`define INTERFACE_STRUCT_PKG
package interface_struct_pkg;
  import core_pkg::*;

// ============================================
//          Pipeline Stage Interfaces
// ============================================

// Decode -> Execute Interface
typedef struct packed {
  logic [MEM_ADDR_WIDTH-1:0]    pc;           // Program Counter
  func_unit_e                   fu;           // Functional Unit
  logic [3:0]                   uOP;          // Micro-OP for FUs
  logic [4:0]                   rs1_addr;     // rs1 address
  logic [INT_REG_WIDTH-1:0]     rs1_data;     // rs1 data from regfile
  logic [4:0]                   rs2_addr;     // rs2 address
  logic [INT_REG_WIDTH-1:0]     rs2_data;     // rs2 data from regfile
  logic [4:0]                   rd_addr;      // rd address
  logic [INT_MAX_IMM_WIDTH-1:0] imm;          // Selected immediate value
  logic                         is_32b;       // Instruction output is 32-bit
  logic                         en_wb;        // Writeback stage enable
} decode_execute_if_t;

// Execute -> Writeback Interface
typedef struct packed {
  logic [4:0]                rd_addr;         // Destination register
  logic                      en_wb;           // Writeback enable
  logic [INT_REG_WIDTH-1:0]  result;          // Result to write back
  
  // NOTE: These branch signals are passed to WB for future OoO/ROB architectural 
  logic [MEM_ADDR_WIDTH-1:0] next_pc;         // Next PC (for branches/jumps)
  logic                      branch_taken;    // Branch was taken
  
  logic                      exception;       // TODO: Handle exceptions in WB/Commit (e.g. traps)
  logic                      valid;           // Overall execute valid
} execute_wb_if_t;

// ============================================
//          Function Unit Interfaces
// ============================================
typedef struct packed {
  logic [INT_REG_WIDTH-1:0] result;           // Computed result
  logic                     valid;            // Output is valid
} fu_alu_out_t;

typedef struct packed {
  logic [MEM_ADDR_WIDTH-1:0] target_pc;       // Branch target
  logic                      taken;           // Branch is taken
  logic                      valid;           // Branch result valid
} fu_branch_out_t;

typedef struct packed {
  logic [MEM_ADDR_WIDTH-1:0] addr;            // Memory address
  logic [INT_REG_WIDTH-1:0]  formatted_data;  // Formatted data from memory
  logic                      exception;       // Exception raised
  logic                      valid;           // Memory request valid
} fu_load_out_t;

typedef struct packed {
  logic [MEM_ADDR_WIDTH-1:0] addr;            // Memory address
  logic [INT_REG_WIDTH-1:0]  data;            // Shifted data to store
  logic [7:0]                be;              // Byte Enables (Write Strobe)
  logic                      exception;       // Exception raise
  logic                      valid;           // Memory request valid
} fu_store_out_t;

endpackage
`endif