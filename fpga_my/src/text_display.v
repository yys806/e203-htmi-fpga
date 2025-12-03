module text_display(
    input  wire clk,
    input  wire [10:0] pixel_x,
    input  wire [9:0]  pixel_y,
    
    // 新增接口：光标信息
    input  wire [6:0]  cursor_x,      // 当前光标在第几列
    input  wire [4:0]  cursor_y,      // 当前光标在第几行
    input  wire        cursor_blink,  // 光标闪烁信号 (1=显示方块, 0=不显示)
    
    // 连接 VRAM
    output wire [11:0] vram_addr,
    input  wire [7:0]  ascii_code,
    
    // 输出像素
    output wire pixel_on
);

    // 1. 计算当前是第几个字 (列, 行)
    wire [6:0] col_idx = pixel_x[9:3]; // pixel_x / 8
    wire [4:0] row_idx = pixel_y[8:4]; // pixel_y / 16
    
    // 2. 算出 VRAM 地址
    assign vram_addr = (row_idx * 100) + col_idx;
    
    // 3. 字符内部位置
    wire [2:0] sub_x = pixel_x[2:0];
    wire [3:0] sub_y = pixel_y[3:0];
    
    // 4. 查字库
    wire [7:0] font_bits;
    font_rom u_font_rom(
        .ascii (ascii_code),
        .row   (sub_y),
        .data  (font_bits)
    );
    
    wire char_pixel = font_bits[7 - sub_x];

    // 5. 光标逻辑 【关键新增】
    // 如果当前扫描位置 == 光标位置
    wire is_cursor_pos = (col_idx == cursor_x) && (row_idx == cursor_y);
    
    // 最终输出逻辑：
    // 如果是光标位置且闪烁状态为亮 -> 显示光标方块 (或者反色)
    // 否则 -> 显示字符本身
    
    // 这里实现“异或”效果：光标亮的时候，黑底变白，白字变黑（反色），这样能看清光标下的字
    assign pixel_on = (is_cursor_pos && cursor_blink) ? ~char_pixel : char_pixel;

endmodule