/**************************************************************************************************
* Module Name    : decode
* Author         : Jacob Dudik
* Creation Date  : 07/05/2026
* Last edit Date : 07/05/2026
* Description    : 
*                  
*                  
**************************************************************************************************/


`ifndef DECODE
`define DECODE
module decode
  import core_pkg::*;
  import interface_struct_pkg::decode_execute_if_t;
  #(
    // ======= Parameters ========
    parameter FETCH_WIDTH = 1
  )
  (
    // ========= Inputs ==========
    input  logic clk,
    input  logic rst_n,

    input  logic flush,
    input  logic stall_i,

    input  logic               [FETCH_WIDTH-1:0]                      instr_valid_i,
    input  logic               [FETCH_WIDTH-1:0] [INSTR_WIDTH-1:0]    instr_i,
    input  logic               [FETCH_WIDTH-1:0] [MEM_ADDR_WIDTH-1:0] instr_pc_i,

    // ========= Outputs =========
    output logic               [FETCH_WIDTH-1:0] instr_valid_o,
    output decode_execute_if_t [FETCH_WIDTH-1:0] DE_if_o
  );

  // ============================================
  //         Internal Signals / Modules            
  // ============================================
  // Stage Output Data 
  decode_execute_if_t [FETCH_WIDTH-1:0]           DE_if_d;

  // Instruction Fields
  logic [FETCH_WIDTH-1:0] [6:0]                   opcode;
  logic [FETCH_WIDTH-1:0] [2:0]                   funct3;
  logic [FETCH_WIDTH-1:0] [7:0]                   funct7;
  logic [FETCH_WIDTH-1:0] [4:0]                   rs1;
  logic [FETCH_WIDTH-1:0] [4:0]                   rs2;
  logic [FETCH_WIDTH-1:0] [4:0]                   rd;
  logic [FETCH_WIDTH-1:0] [INT_MAX_IMM_WIDTH-1:0] imm_i_type;
  logic [FETCH_WIDTH-1:0] [INT_MAX_IMM_WIDTH-1:0] imm_s_type;
  logic [FETCH_WIDTH-1:0] [INT_MAX_IMM_WIDTH-1:0] imm_b_type;
  logic [FETCH_WIDTH-1:0] [INT_MAX_IMM_WIDTH-1:0] imm_u_type;
  logic [FETCH_WIDTH-1:0] [INT_MAX_IMM_WIDTH-1:0] imm_j_type;

  // Instantiate the interger register file and its signals
  logic [FETCH_WIDTH-1:0] [INT_REG_WIDTH-1:0] rs1_rd_data;
  logic [FETCH_WIDTH-1:0] [INT_REG_WIDTH-1:0] rs2_rd_data;

  // TODO: fix port, addr, and reg sizing when moving to multiple fetch
  int_regfile #(
    .RD_PORTS(2),
    .WR_PORTS(1),
    .NUM_REGS(INT_REGS)
  ) regfile (
    .clk        (clk),
    .rst_n      (rst_n),
    .rd_addr_i  ({rs1[0], rs2[0]}),
    .rd_data_i  ({rs1_rd_data[0], rs2_rd_data[0]}),

    // TODO: get writeback working
    .wr_valid_i (),
    .wr_addr_i  (),
    .wr_data_i  ()
  );

  // ============================================
  //          Parse Instruction Fields         
  // ============================================
  always_comb begin
    for (int idx = 0; idx < FETCH_WIDTH; idx++) begin
      opcode[idx] = instr_i[idx][6:0];
      funct3[idx] = instr_i[idx][14:12];
      funct7[idx] = instr_i[idx][31:25];
      rs1[idx]    = instr_i[idx][19:15];
      rs2[idx]    = instr_i[idx][24:20];
      rd[idx]     = instr_i[idx][11:7];
      
      // =======================================
      //  Parse Immediates
      //  - Sign-extended to 64-bits in EXECUTE
      //  - u-type also zero-extends lower bits
      // =======================================
      imm_i_type[idx] = {
                          9'{instr_i[idx][31]},   // imm[19:11]
                          instr_i[idx][30:20]     // imm[10:0]
                        };

      imm_s_type[idx] = {
                          9'{instr_i[idx][31]},   // imm[19:11]
                          instr_i[idx][30:25],    // imm[10:5]
                          instr_i[idx][11:7]      // imm[4:0]
                        };
      
      imm_b_type[idx] = { 
                          8'{instr_i[idx][31]},   // imm[19:12]
                          instr_i[idx][7],        // imm[11]
                          instr_i[idx][30:25],    // imm[10:5]
                          instr_i[idx][11:8],     // imm[4:1]
                          1'b0                    // imm[0]
                        };

      imm_u_type[idx] =   instr_i[idx][31:12];    // imm[31:12]
      
      imm_j_type[idx] = {
                          instr_i[idx][19:12],    // imm[19:12]
                          instr_i[idx][20],       // imm[11]
                          instr_i[idx][30:25],    // imm[10:5]
                          instr_i[idx][24:21],    // imm[4:1]
                          1'b0                    // imm[0]
                        };
    end
  end

  // ==================================================
  //        Assign the output stage next data
  // ==================================================
  always_comb begin
    // ---------------------------------------------
    // Generate control signals/imm based on OPCODE
    // ---------------------------------------------
    for (int idx = 0; idx < FETCH_WIDTH; idx++) begin
      DE_if_d[idx].uOP    = { 1'b0, funct3[idx] };
      DE_if_d[idx].fu     = NONE;
      DE_if_d[idx].imm    = '0;
      DE_if_d[idx].is_32b = '0;
      DE_if_d[idx].en_wb  = '0;

      case (opcode)
        OP: begin
          DE_if_d[idx].uOP   = {instr_i[idx][30], funct3[idx]};
          DE_if_d[idx].fu    = ALU;
          DE_if_d[idx].en_wb = '1;
        end

        OP_32: begin
          DE_if_d[idx].uOP    = {instr_i[idx][30], funct3[idx]};
          DE_if_d[idx].fu     = ALU;
          DE_if_d[idx].is_32b = '1;
          DE_if_d[idx].en_wb  = '1;
        end

        // I-type opcodes
        OP_IMM: begin
          DE_if_d[idx].fu    = ALU;
          DE_if_d[idx].en_wb = '1;

          // TODO/NOTE: can probably get rid of this since ALU could just do this
          if (funct3[idx] == 3'b001) ||  // SLL
             (funct3[idx] == 3'b101)     // SRL/SRA
          begin
            DE_if_d[idx].uOP = {instr_i[idx][30], funct3[idx]};
            DE_if_d[idx].imm = {14'b0, imm_i_type[idx][5:0]};
          end else begin
            DE_if_d[idx].imm = imm_i_type[idx];
          end
        end

        OP_IMM_32: begin
          DE_if_d[idx].fu     = ALU;
          DE_if_d[idx].is_32b = '1;
          DE_if_d[idx].en_wb  = '1;

          // TODO/NOTE: can probably get rid of this since ALU could just do this
          if (funct3[idx] == 3'b001) ||  // SLL
             (funct3[idx] == 3'b101)     // SRL/SRA
          begin
            DE_if_d[idx].uOP = {instr_i[idx][30], funct3[idx]};
            DE_if_d[idx].imm = {15'b0, imm_i_type[idx][4:0]};
          end else begin
            DE_if_d[idx].imm = imm_i_type[idx];
          end
        end
        
        LOAD: begin
          DE_if_d[idx].fu    = LOAD;
          DE_if_d[idx].imm   = imm_i_type[idx];
          DE_if_d[idx].en_wb = '1;
        end

        STORE: begin
          DE_if_d[idx].fu    = STORE;
          DE_if_d[idx].imm   = imm_s_type[idx];
        end

        BRANCH: begin
          DE_if_d[idx].fu  = BRANCH;
          DE_if_d[idx].imm = imm_b_type[idx];
        end

        JAL: begin
          DE_if_d[idx].uOP   = 4'h2;
          DE_if_d[idx].fu    = BRANCH;
          DE_if_d[idx].imm   = imm_j_type[idx];
          DE_if_d[idx].en_wb = '1;
        end

        JALR: begin
          DE_if_d[idx].uOP   = 4'h3;
          DE_if_d[idx].fu    = BRANCH;
          DE_if_d[idx].imm   = imm_i_type[idx];
          DE_if_d[idx].en_wb = '1;
        end

        LUI: begin
          DE_if_d[idx].uOP   = 4'b1_001;
          DE_if_d[idx].fu    = ALU;
          DE_if_d[idx].imm   = imm_u_type[idx];
          DE_if_d[idx].en_wb = '1;
        end

        AUIPC: begin
          DE_if_d[idx].uOP   = 4'b1_010;
          DE_if_d[idx].fu    = ALU;
          DE_if_d[idx].imm   = imm_u_type[idx];
          DE_if_d[idx].en_wb = '1;
        end

        SYSTEM: begin
          DE_if_d[idx].fu  = SYS;
          DE_if_d[idx].imm = imm_i_type[idx];
        end

        MISC_MEM: begin
          // TODO
        end
      endcase

      // ------------------------------------------
      //  Assign regfile reads to output interface
      // ------------------------------------------
      
      // TODO: need to take into account forwarding/in-flight instructions
      DE_if_d[idx].rs1_addr = rs1[idx];
      DE_if_d[idx].rs1_data = rs1_rd_data[idx];

      DE_if_d[idx].rs2_addr = rs2[idx];
      DE_if_d[idx].rs2_data = rs2_rd_data[idx];
      
      DE_if_d[idx].rd_addr  = rd[idx];
    end
  end
  
  // ============================================
  //             Output Register Stage         
  // ============================================
  
  // Always pass along valid unless a stall or flush occurs
  always_ff @(posedge clk) begin
    if (!rst_n || flush) begin
      instr_valid_o <= '0;
    end else if (!stall_i) begin
      instr_valid_o <= instr_valid_i;
    end
  end

  // Pass data along when the new instruction is valid, otherwise clock gate
  always_ff @(posedge clk) begin
    for (int idx = 0; idx < FETCH_WIDTH; idx++) begin
      if (!stall_i) begin
        DE_if_o[idx] <= instr_valid_i[idx] ? DE_if_d[idx] : DE_if_o[idx]; 
      end
    end
  end

endmodule
`endif