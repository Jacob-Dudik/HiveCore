`ifndef CORE_PKG
`define CORE_PKG
package core_pkg;

//=========================================
//       RV64I Base ISA Definitions
//=========================================
parameter INSTR_WIDTH           = 32;   // Instruction width
parameter MEM_ADDR_WIDTH        = 64;   // 64-bit address space 

parameter INT_REGS              = 32;   // Number of architected integer registers
parameter INT_REG_ADDR_WIDTH    = 5;    // Architected register address width
parameter INT_REG_WIDTH         = 64;   // Register data width (XLEN = 64)
parameter INT_MAX_IMM_WIDTH     = 20;   // Max width of an immediate value in an instruction
                                        // - Not all immediate values are this length (ex. I-type imm == 12-bits)

//=========================================
//       Instruction Type Structs
//=========================================

// OPCODES
localparam OP_W = 7;
typedef enum logic [OP_W-1:0] {
  //  I-Extension Opcodes
  OP        = 7'b01_100_11, // R-type (Reg-Reg w/ 64-bit)
  OP_32     = 7'b01_110_11, // R-type (Reg-Reg w/ 32-bit)
  
  OP_IMM    = 7'b00_100_11, // I-type (Reg-Immediate 64-bit)
  OP_IMM_32 = 7'b00_110_11, // I-type (Reg-Immediate 32-bit) 

  LOAD      = 7'b00_000_11, // I-type (load)
  STORE     = 7'b01_000_11, // S-type

  BRANCH    = 7'b11_000_11, // B-type
 
  JAL       = 7'b11_011_11, // J-type
  JALR      = 7'b11_001_11, // I-type (jump and link register)

  LUI       = 7'b01_101_11, // U-type (load upper immediate)
  AUIPC     = 7'b00_101_11, // U-type (add upper immediate to pc)

  SYSTEM    = 7'b11_100_11, // I-type (environment call/break)
  MISC_MEM  = 7'b00_011_11
} opcode_e;

// FUNCTION 3
typedef enum logic [3:0] {
  ALU_ADD   = 4'b0_000,
  ALU_SLL   = 4'b0_001,
  ALU_SLT   = 4'b0_010,
  ALU_SLTU  = 4'b0_011,
  ALU_XOR   = 4'b0_100,
  ALU_SRL   = 4'b0_101,
  ALU_OR    = 4'b0_110,
  ALU_AND   = 4'b0_111,
  ALU_SUB   = 4'b1_000,
  ALU_SRA   = 4'b1_101,
  ALU_LUI   = 4'b1_001,
  ALU_AUIPC = 4'b1_010
} alu_uOP_e;

typedef enum logic [3:0] {
  LSU_LB_SB = 4'h0,
  LSU_LH_SH = 4'h1,
  LSU_LW_SW = 4'h2,
  LSU_LD_SD = 4'h3,
  LSU_LBU   = 4'h4,
  LSU_LHU   = 4'h5,
  LSU_LWU   = 4'h6
} lsu_uOP_e;

typedef enum logic [3:0] {
  // Branches
  BEQ       = 4'h0,
  BNE       = 4'h1,
  BLT       = 4'h4,
  BGE       = 4'h5,
  BLTU      = 4'h6,
  BGEU      = 4'h7,

  // Jumps
  JAL       = 4'h2,
  JALR      = 4'h3
} branch_uOP_e;

// Functional Unit Identifiers
typedef enum logic [2:0] {
  NONE,
  ALU,
  LOAD,
  STORE,
  BRANCH,
  MUL,
  DIV,
  SYS
} func_unit_e;

//=========================================
//       Reorder Buffer Definitons
//=========================================
parameter ROB_SIZE      = 64;
parameter ROB_PTR_WIDTH = $clog2(ROB_SIZE); 

endpackage
`endif