`timescale 1ns/1ps
module DataMem(
    input clk,mem_wen,mem_ren, //时钟，写使能（高有效），读使能（高有效）
    input [31:0] mem_addr, //地址
    input [31:0] mem_data_i, //写入数据
    output reg[31:0] mem_data_o //读出数据
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
