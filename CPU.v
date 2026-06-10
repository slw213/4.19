`timescale 1ns/1ps
module CPU(
    input clk,
    input rst
);
    // ifu
    wire [31:0] inst;
    // Control
    wire ct_rf_wen, ct_alu_src, ct_data_rf, ct_branch, ct_jump, ct_mem_wen, ct_mem_ren;
    wire [1:0] ct_alu_op;
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
        .ct_data_rf(ct_data_rf),.ct_branch(ct_branch),.ct_jump(ct_jump),.ext_data(ext_data)
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
