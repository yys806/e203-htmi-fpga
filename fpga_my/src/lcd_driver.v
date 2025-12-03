module lcd_driver(
    input  wire clk,        // 像素时钟 (27MHz)
    input  wire rst_n,      // 复位信号 (低电平有效)
    
    output wire lcd_de,     // 数据有效信号 (High Active)
    output wire lcd_hs,     // 行同步信号 (Low Active)
    output wire lcd_vs,     // 场同步信号 (Low Active)
    output wire [10:0] pixel_x, // 当前像素 X 坐标
    output wire [9:0]  pixel_y  // 当前像素 Y 坐标
);

    // ============================================
    // 时序参数定义 (适配 27MHz 时钟)
    // 计算公式: 刷新率 = DCLK / (H_Total * V_Total)
    // 目标: 27,000,000 / (880 * 512) = 59.92 Hz (完美!)
    // ============================================
    
    // 水平方向 (Horizontal)
    parameter H_Vis   = 800; // 可视区域
    parameter H_Front = 40;  // 前沿
    parameter H_Sync  = 4;   // 同步脉冲
    parameter H_Back  = 36;  // 后沿
    parameter H_Total = 880; // 总周期

    // 垂直方向 (Vertical)
    parameter V_Vis   = 480; // 可视区域
    parameter V_Front = 12;  // 前沿
    parameter V_Sync  = 4;   // 同步脉冲
    parameter V_Back  = 16;  // 后沿
    parameter V_Total = 512; // 总周期

    // 计数器
    reg [10:0] cnt_h;
    reg [9:0]  cnt_v;

    // 行计数器逻辑
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) 
            cnt_h <= 11'd0;
        else begin
            if(cnt_h == H_Total - 1) 
                cnt_h <= 11'd0;
            else 
                cnt_h <= cnt_h + 1'b1;
        end
    end

    // 场计数器逻辑
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) 
            cnt_v <= 10'd0;
        else begin
            if(cnt_h == H_Total - 1) begin
                if(cnt_v == V_Total - 1) 
                    cnt_v <= 10'd0;
                else 
                    cnt_v <= cnt_v + 1'b1;
            end
        end
    end

    // 信号生成
    // HSYNC 和 VSYNC 为负极性 (低电平有效)，所以在计数值小于 Sync 脉冲宽度时拉低
    assign lcd_hs = ~(cnt_h < H_Sync);
    assign lcd_vs = ~(cnt_v < V_Sync);
    
    // DE (Data Enable) 数据有效区
    // 只有在扫描到可视区域时，DE 才为高电平
    assign lcd_de = (cnt_h >= (H_Sync + H_Back)) && 
                    (cnt_h < (H_Sync + H_Back + H_Vis)) &&
                    (cnt_v >= (V_Sync + V_Back)) && 
                    (cnt_v < (V_Sync + V_Back + V_Vis));

    // 坐标输出 (将时序坐标转换为像素坐标 0~799, 0~479)
    // 只有在 DE 有效时输出有效坐标，否则输出 0
    assign pixel_x = lcd_de ? (cnt_h - (H_Sync + H_Back)) : 11'd0;
    assign pixel_y = lcd_de ? (cnt_v - (V_Sync + V_Back)) : 10'd0;

endmodule