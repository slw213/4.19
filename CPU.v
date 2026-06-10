`timescale 1ns/1ps

// ============= IFU (Instruction Fetch Unit) =============
module IFU(
    input        clk,
    input        rst,
    input        alu_zero,
    input        ct_branch,
    input        ct_jump,
    input  [31:0] ext_data,  
    output [31:0] inst
);
    reg [31:0] pc;
    reg [31:0] instRom [65535:0];

    initial begin
        $readmemh("inst.data",instRom);
    end

    assign inst = instRom[pc[17:2]];

    always@(posedge clk) begin
        if(!rst) begin
            pc <= 32'd0;
        end else begin
            if(ct_jump) begin
                pc <= pc + ext_data;  
            end else if(ct_branch && alu_zero) begin
                pc <= pc + ext_data;  
            end else begin
                pc <= pc + 32'd4;
            end
        end
    end

endmodule


// ============= Control Unit =============
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
    output [1:0] EXTOp,
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
    // BUG FIX: B-type immediate sign extension should be 20 bits, not 19
    wire [31:0] bimm = {{20{ct_inst[31]}}, ct_inst[31], ct_inst[7], ct_inst[30:25], ct_inst[11:8], 1'b0};
    // BUG FIX: J-type immediate sign extension should be 12 bits, not 11
    wire [31:0] jimm = {{12{ct_inst[31]}}, ct_inst[31], ct_inst[19:12], ct_inst[20], ct_inst[30:21], 1'b0};

    assign ext_data = (is_addi | is_lw | is_srai) ? iimm :
                      is_sw            ? simm :
                      is_beq           ? bimm :
                      is_jal           ? jimm :
                      32'b0;

    // 立即数扩展操作类型
    assign EXTOp = is_jal  ? 2'b11 :
                   is_beq  ? 2'b10 :
                   is_sw   ? 2'b01 :
                   2'b00;

endmodule


// ============= ALU Control =============
module ALUCt (
    input        rst,
    input [1:0]  alu_op,
    input [2:0]  funct3,    
    input [6:0]  funct7,    
    output reg [3:0] ct_alu
);

    always @(*) begin
        case(alu_op)
            2'b00: ct_alu = 4'b0010;      // add for lw/sw
            2'b01: ct_alu = 4'b0110;      // sub for beq
            2'b10: begin                   // R-type instructions
                if(funct7 == 7'b0000000 && funct3 == 3'b000)
                    ct_alu = 4'b0010;     // add
                else if(funct7 == 7'b0000000 && funct3 == 3'b100)
                    ct_alu = 4'b0100;     // xor
                else
                    ct_alu = 4'b0000;
            end
            2'b11: begin                   // I-type special instructions (srai)
                if(funct7 == 7'b0100000 && funct3 == 3'b101)
                    ct_alu = 4'b0101;     // srai
                else
                    ct_alu = 4'b0000;
            end
            default: ct_alu = 4'b0000;
        endcase
    end
endmodule


// ============= Register File =============
module RegFile(
    input        clk,
    input        rf_wen,
    input  [4:0] rf_addr_r1,
    input  [4:0] rf_addr_r2,
    input  [4:0] rf_addr_w,
    input  [31:0] rf_data_w,
    output  [31:0] rf_data_r1,
    output  [31:0] rf_data_r2
);
    reg[31:0] regs[0:31];
    integer i;
    
    initial begin
        for(i=0;i<32;i=i+1)
            regs[i]=32'd0;
    end
    
    //读操作
    assign rf_data_r1=(rf_addr_r1==5'd0)?32'd0:regs[rf_addr_r1];
    assign rf_data_r2=(rf_addr_r2==5'd0)?32'd0:regs[rf_addr_r2];
    
    // BUG FIX: Register write should happen on posedge clk (rising edge), not negedge clk
    // This ensures proper synchronization with instruction decode and ALU result generation
    always@(posedge clk) begin
        if (rf_wen && (rf_addr_w!=5'd0)) begin
            regs[rf_addr_w] <= rf_data_w;
        end
    end
endmodule


// ============= ALU =============
module ALU(
    input           rst,
    input     [3:0]  alu_ct,
    input     [31:0] alu_src1,
    input     [31:0] alu_src2,
    output           alu_zero,
    output reg[31:0] alu_res
);
    assign alu_zero=(alu_res==32'd0)?1'b1:1'b0;
    
    always@(*) begin
        case(alu_ct)
            4'b0010: alu_res = alu_src1 + alu_src2;           // add
            4'b0110: alu_res = alu_src1 - alu_src2;           // sub
            4'b0100: alu_res = alu_src1 ^ alu_src2;           // xor
            4'b0101: alu_res = $signed(alu_src1) >>> alu_src2[4:0];  // srai
            default: alu_res = 32'd0;
        endcase
    end
endmodule


// ============= Data Memory =============
module DataMem(
    input clk,mem_wen,mem_ren,
    input [31:0] mem_addr,
    input [31:0] mem_data_i,
    output reg[31:0] mem_data_o
);
    //4个字节存储器，每个存储器深度65536
    reg[7:0] data_mem0 [0:65535];
    reg[7:0] data_mem1 [0:65535];
    reg[7:0] data_mem2 [0:65535];
    reg[7:0] data_mem3 [0:65535];
    
    //写操作：时钟下降沿触发
    always@(negedge clk) begin
        if(mem_wen) begin
            data_mem0[mem_addr[18:2]]<=mem_data_i[7:0];
            data_mem1[mem_addr[18:2]]<=mem_data_i[15:8];
            data_mem2[mem_addr[18:2]]<=mem_data_i[23:16];
            data_mem3[mem_addr[18:2]]<=mem_data_i[31:24];
        end
    end
    
    //读操作：异步读，mem_ren=0时输出0
    always@(*) begin
        if(mem_ren) begin
            mem_data_o={
                data_mem3[mem_addr[18:2]],
                data_mem2[mem_addr[18:2]],
                data_mem1[mem_addr[18:2]],
                data_mem0[mem_addr[18:2]]
            };
        end else begin
            mem_data_o=32'd0;
        end
    end
endmodule


// ============= CPU Top Module =============
module CPU(
    input clk,
    input rst
);
    // ifu
    wire [31:0] inst;
    // Control
    wire ct_rf_wen, ct_alu_src, ct_data_rf, ct_branch, ct_jump, ct_mem_wen, ct_mem_ren;
    wire [1:0] ct_alu_op;
    wire [1:0] ct_ext_op;
    wire [3:0] ct_alu;
    // RegFile
    wire [4:0]  rf_addr_w;
    wire [31:0] rf_data_r1, rf_data_r2, rf_data_w;
    // ALU
    wire alu_zero;
    wire [31:0] alu_src2;
    wire [31:0] alu_res;
    // 立即数
    wire [31:0] ext_data;
    // DataMem
    wire [31:0] mem_data_o;

    assign rf_addr_w = inst[11:7];
    assign rf_data_w = ct_data_rf ? mem_data_o : alu_res;
    assign alu_src2  = ct_alu_src ? ext_data : rf_data_r2;

    IFU ifu0(
        .clk(clk),.rst(rst),.alu_zero(alu_zero),
        .ct_branch(ct_branch),.ct_jump(ct_jump),
        .ext_data(ext_data),  
        .inst(inst)
    );

    Control ct0(
        .rst(rst),.ct_inst(inst),.ct_rf_wen(ct_rf_wen),.ct_alu_src(ct_alu_src),
        .ct_alu_op(ct_alu_op),.ct_mem_wen(ct_mem_wen),.ct_mem_ren(ct_mem_ren),
        .ct_data_rf(ct_data_rf),.ct_branch(ct_branch),.ct_jump(ct_jump),
        .EXTOp(ct_ext_op),
        .ext_data(ext_data)
    );

    ALUCt aluct0(
        .rst(rst),.alu_op(ct_alu_op),.funct3(inst[14:12]),.funct7(inst[31:25]),
        .ct_alu(ct_alu)
    );

    RegFile rf0(
        .clk(clk),.rf_wen(ct_rf_wen),
        .rf_addr_r1(inst[19:15]),.rf_addr_r2(inst[24:20]),.rf_addr_w(rf_addr_w),
        .rf_data_w(rf_data_w),.rf_data_r1(rf_data_r1),.rf_data_r2(rf_data_r2)
    );

    ALU alu0(
        .rst(rst),.alu_ct(ct_alu),.alu_src1(rf_data_r1),.alu_src2(alu_src2),
        .alu_zero(alu_zero),.alu_res(alu_res)
    );

    DataMem datamem0(
        .clk(clk),.mem_wen(ct_mem_wen),.mem_ren(ct_mem_ren),
        .mem_addr(alu_res),.mem_data_i(rf_data_r2),.mem_data_o(mem_data_o)
    );

endmodule
