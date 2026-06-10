`timescale 1ns / 1ps
module Control(
    input  rst,
    input  [31:0] ct_inst,
    output ct_rf_wen,
    output ct_alu_src,
    output [1:0] ct_alu_op,
    output ct_mem_wen,
    output ct_mem_ren,
    output ct_data_rf,
    output ct_branch,
    output ct_jump,
    output [31:0] ext_data
);    
    localparam OP_RTYPE  = 7'b0110011;
    localparam OP_ITYPE  = 7'b0010011;
    localparam OP_LW     = 7'b0000011;
    localparam OP_SW     = 7'b0100011;
    localparam OP_BRANCH = 7'b1100011;
    localparam OP_JAL    = 7'b1101111;

    localparam FUNCT3_ADD = 3'b000;
    localparam FUNCT3_XOR = 3'b100;
    localparam FUNCT3_SRAI = 3'b101;
    localparam FUNCT3_LW  = 3'b010;
    localparam FUNCT3_SW  = 3'b010;
    localparam FUNCT3_BEQ = 3'b000;
    localparam FUNCT7_ADD = 7'b0000000;
    localparam FUNCT7_XOR = 7'b0000000;
    localparam FUNCT7_SRAI = 7'b0100000;

    wire [6:0] Op     = ct_inst[6:0];
    wire [2:0] Funct3 = ct_inst[14:12];
    wire [6:0] Funct7 = ct_inst[31:25];

    wire is_add  = (Op == OP_RTYPE)  & (Funct3 == FUNCT3_ADD) & (Funct7 == FUNCT7_ADD);
    wire is_addi = (Op == OP_ITYPE)  & (Funct3 == FUNCT3_ADD);
    wire is_xor  = (Op == OP_RTYPE)  & (Funct3 == FUNCT3_XOR) & (Funct7 == FUNCT7_XOR);
    wire is_srai = (Op == OP_ITYPE)  & (Funct3 == FUNCT3_SRAI) & (Funct7 == FUNCT7_SRAI);
    wire is_lw   = (Op == OP_LW)     & (Funct3 == FUNCT3_LW);
    wire is_sw   = (Op == OP_SW)     & (Funct3 == FUNCT3_SW);
    wire is_beq  = (Op == OP_BRANCH) & (Funct3 == FUNCT3_BEQ);
    wire is_jal  = (Op == OP_JAL);

    assign ct_rf_wen  = rst ? (is_add | is_lw | is_addi | is_xor | is_srai) : 1'b0;
    assign ct_alu_src = (is_addi | is_lw | is_sw | is_srai);
    assign ct_alu_op  = (is_add) ? 2'b10 :
                        (is_xor) ? 2'b10 :
                        (is_srai) ? 2'b11 :
                        (is_beq) ? 2'b01 :
                        2'b00;
    assign ct_branch  = is_beq;
    assign ct_mem_ren = is_lw;
    assign ct_mem_wen = is_sw;
    assign ct_data_rf = is_lw;
    assign ct_jump    = is_jal;

    // 立即数拼接 
    wire [31:0] iimm = {{20{ct_inst[31]}}, ct_inst[31:20]};
    wire [31:0] simm = {{20{ct_inst[31]}}, ct_inst[31:25], ct_inst[11:7]};
    wire [31:0] bimm = {{19{ct_inst[31]}}, ct_inst[31], ct_inst[7], ct_inst[30:25], ct_inst[11:8], 1'b0};
    wire [31:0] jimm = {{11{ct_inst[31]}}, ct_inst[31], ct_inst[19:12], ct_inst[20], ct_inst[30:21], 1'b0};

    assign ext_data = is_addi | is_lw | is_srai ? iimm :
                      is_sw            ? simm :
                      is_beq           ? bimm :
                      is_jal           ? jimm :
                      32'b0;

endmodule
