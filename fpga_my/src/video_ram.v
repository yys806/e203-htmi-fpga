module video_ram(
    input  wire clk,
    
    // 写端口 (来自 CPU/串口逻辑)
    input  wire [11:0] w_addr,
    input  wire [7:0]  w_data,
    input  wire        w_en,
    
    // 读端口 0 (给显示模块用)
    input  wire [11:0] r_addr_0,
    output reg  [7:0]  r_data_0,

    // 【新增】读端口 1-5 (给指令匹配逻辑用)
    input  wire [11:0] r_addr_1,
    output reg  [7:0]  r_data_1,
    input  wire [11:0] r_addr_2,
    output reg  [7:0]  r_data_2,
    input  wire [11:0] r_addr_3,
    output reg  [7:0]  r_data_3,
    input  wire [11:0] r_addr_4,
    output reg  [7:0]  r_data_4,
    input  wire [11:0] r_addr_5,
    output reg  [7:0]  r_data_5
);

    // BRAM: 100列 * 30行 = 3000 字节
    reg [7:0] mem [0:2999];

    // 写操作 (同步写)
    always @(posedge clk) begin
        if(w_en) mem[w_addr] <= w_data;
    end

    // 读操作 (同步读，所有端口并行)
    always @(posedge clk) begin
        r_data_0 <= mem[r_addr_0];
        r_data_1 <= mem[r_addr_1];
        r_data_2 <= mem[r_addr_2];
        r_data_3 <= mem[r_addr_3];
        r_data_4 <= mem[r_addr_4];
        r_data_5 <= mem[r_addr_5];
    end

endmodule