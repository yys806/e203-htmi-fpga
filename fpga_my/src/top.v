module top(
    input  wire clk,          // 27MHz
    input  wire uart_rx_pin,  // T13
    
    output wire lcd_dclk,
    output wire lcd_hs, lcd_vs, lcd_de, lcd_bl,
    output wire [4:0] lcd_r,
    output wire [5:0] lcd_g,
    output wire [4:0] lcd_b
);

    // 1. 时钟与复位
    wire pclk;
    wire sys_rst_n = 1'b1;
    Gowin_rPLL u_pll(.clkout(pclk), .clkin(clk));

    // 2. 串口接收
    wire [7:0] rx_data;
    wire       rx_valid;
    uart_rx u_uart(.clk(pclk), .rx_pin(uart_rx_pin), .data(rx_data), .valid(rx_valid));

    // =====================================================
    // 3. 静态数据定义
    // =====================================================
    localparam PROMPT_LEN = 17;
    function [7:0] get_prompt_char;
        input [4:0] idx;
        begin
            case(idx)
                0: get_prompt_char = "r"; 1: get_prompt_char = "o"; 2: get_prompt_char = "o"; 3: get_prompt_char = "t"; 4: get_prompt_char = "@"; 5: get_prompt_char = "s"; 6: get_prompt_char = "h"; 7: get_prompt_char = "e"; 8: get_prompt_char = "n"; 9: get_prompt_char = "_"; 10: get_prompt_char = "k"; 11: get_prompt_char = "a"; 12: get_prompt_char = "i"; 13: get_prompt_char = ":"; 14: get_prompt_char = "~"; 15: get_prompt_char = "#"; 16: get_prompt_char = " ";
                default: get_prompt_char = 0;
            endcase
        end
    endfunction
    reg [25*8-1:0] str_line1 = "Simulation Linux Terminal"; 
    reg [43*8-1:0] str_line2 = "By 2352396 Yu Yaoshen And 2351283 Wu Kai";

    // =====================================================
    // 4. 终端主逻辑 (增加 clear 指令判断)
    // =====================================================
    reg [6:0] cursor_x;
    reg [4:0] cursor_y;
    reg [11:0] write_addr;
    reg [7:0]  write_data;
    reg        write_en;
    reg [2:0]  state;
    localparam S_INIT = 0, S_SHOW_INFO = 1, S_WAIT_READ = 2, S_CLEAR_ALL = 3, S_PROMPT = 4, S_IDLE = 5; 
    reg [11:0] process_cnt;
    reg [27:0] timer_cnt;
    reg [11:0] rel_cnt;

    // --- 【新增】指令匹配逻辑 ---
    wire [7:0] char_at_cursor_minus_1, char_at_cursor_minus_2, char_at_cursor_minus_3, char_at_cursor_minus_4, char_at_cursor_minus_5;
    
    // 指令 'clear' (长度5), 且必须在提示符后输入
    wire is_clear_cmd = (cursor_x == (PROMPT_LEN + 5)) && 
                        (char_at_cursor_minus_5 == "c") &&
                        (char_at_cursor_minus_4 == "l") &&
                        (char_at_cursor_minus_3 == "e") &&
                        (char_at_cursor_minus_2 == "a") &&
                        (char_at_cursor_minus_1 == "r");

    always @(posedge pclk) begin
        write_en <= 0;
        
        if (sys_rst_n == 0) begin state <= S_INIT; timer_cnt <= 0; end
        else begin
            case(state)
                S_INIT: if (timer_cnt < 28'd135_000_000) timer_cnt <= timer_cnt + 1; else begin state <= S_SHOW_INFO; process_cnt <= 0; timer_cnt <= 0; end
                S_SHOW_INFO: begin
                    if (process_cnt < 25) begin write_addr <= (12*100) + (37+process_cnt); write_data <= str_line1[(24-process_cnt)*8 +: 8]; write_en <= 1; process_cnt <= process_cnt + 1; end
                    else if (process_cnt < 68) begin rel_cnt = process_cnt-25; write_addr <= (14*100)+(28+rel_cnt); write_data <= str_line2[(42-rel_cnt)*8 +: 8]; write_en <= 1; process_cnt <= process_cnt + 1; end
                    else begin state <= S_WAIT_READ; timer_cnt <= 0; end
                end
                S_WAIT_READ: if (timer_cnt < 28'd81_000_000) timer_cnt <= timer_cnt + 1; else begin state <= S_CLEAR_ALL; process_cnt <= 0; end
                S_CLEAR_ALL: if (process_cnt < 3000) begin write_addr <= process_cnt; write_data <= 8'h00; write_en <= 1; process_cnt <= process_cnt + 1; end else begin state <= S_PROMPT; process_cnt <= 0; cursor_x <= 0; cursor_y <= 0; end
                S_PROMPT: if (process_cnt < PROMPT_LEN) begin write_addr <= (cursor_y*100)+cursor_x; write_data <= get_prompt_char(process_cnt[4:0]); write_en <= 1; cursor_x <= cursor_x + 1; process_cnt <= process_cnt + 1; end else state <= S_IDLE;
                
                S_IDLE: begin
                    if (rx_valid) begin
                        if (rx_data == 8'h0D || rx_data == 8'h0A) begin
                            if (is_clear_cmd) begin
                                state <= S_CLEAR_ALL;
                                process_cnt <= 0;
                            end else begin
                                cursor_x <= 0; 
                                if (cursor_y < 29) cursor_y <= cursor_y + 1;
                                else cursor_y <= 0; 
                                process_cnt <= 0;
                                state <= S_PROMPT; 
                            end
                        end
                        else if (rx_data == 8'h08 || rx_data == 8'h7F) begin
                            if (cursor_x > PROMPT_LEN) begin cursor_x <= cursor_x - 1; write_addr <= (cursor_y * 100) + (cursor_x - 1); write_data <= 8'h00; write_en <= 1; end
                            else if (cursor_x == 0 && cursor_y > 0) begin cursor_y <= cursor_y - 1; cursor_x <= 99; write_addr <= ((cursor_y - 1) * 100) + 99; write_data <= 8'h00; write_en <= 1; end
                        end
                        else if (rx_data >= 8'h20 && rx_data <= 8'h7E) begin
                            write_addr <= (cursor_y * 100) + cursor_x; write_data <= rx_data; write_en <= 1;
                            if (cursor_x < 99) cursor_x <= cursor_x + 1;
                            else begin cursor_x <= 0; if (cursor_y < 29) cursor_y <= cursor_y + 1; else cursor_y <= 0; end
                        end
                    end
                end
            endcase
        end
    end

    // =====================================================
    // 5. 显示子系统 (VRAM 连接修改)
    // =====================================================
    wire [10:0] x;
    wire [9:0]  y;
    lcd_driver u_driver(.clk(pclk), .rst_n(sys_rst_n), .lcd_hs(lcd_hs), .lcd_vs(lcd_vs), .lcd_de(lcd_de), .pixel_x(x), .pixel_y(y));

    wire [11:0] vram_r_addr_0;
    wire [7:0]  vram_r_data_0;
    
    video_ram u_vram(
        .clk(pclk),
        .w_en(write_en), .w_addr(write_addr), .w_data(write_data),
        // 端口0 (显示)
        .r_addr_0(vram_r_addr_0),
        .r_data_0(vram_r_data_0),
        // 端口1-5 (指令匹配)
        .r_addr_1((cursor_y * 100) + cursor_x - 1), .r_data_1(char_at_cursor_minus_1),
        .r_addr_2((cursor_y * 100) + cursor_x - 2), .r_data_2(char_at_cursor_minus_2),
        .r_addr_3((cursor_y * 100) + cursor_x - 3), .r_data_3(char_at_cursor_minus_3),
        .r_addr_4((cursor_y * 100) + cursor_x - 4), .r_data_4(char_at_cursor_minus_4),
        .r_addr_5((cursor_y * 100) + cursor_x - 5), .r_data_5(char_at_cursor_minus_5)
    );
    
    reg [24:0] blink_cnt;
    always @(posedge pclk) blink_cnt <= blink_cnt + 1'b1;
    wire blink_en = blink_cnt[24] && (state == S_IDLE); 

    wire is_pixel_on;
    text_display u_text(
        .clk(pclk), .pixel_x(x), .pixel_y(y),
        .cursor_x(cursor_x), .cursor_y(cursor_y), .cursor_blink(blink_en),
        .vram_addr(vram_r_addr_0),
        .ascii_code(vram_r_data_0),
        .pixel_on(is_pixel_on)
    );

    // =====================================================
    // 6. 画面输出
    // =====================================================
    assign lcd_dclk = pclk;
    assign lcd_bl   = 1'b1;
    wire show_bar = (state == S_INIT);
    wire [15:0] color_bar_data = (x<100)?16'hFFFF:(x<200)?16'hFFE0:(x<300)?16'h07FF:(x<400)?16'h07E0:(x<500)?16'hF81F:(x<600)?16'hF800:(x<700)?16'h001F:16'h0000;
    wire [15:0] text_data = is_pixel_on ? 16'hFFFF : 16'h0000; 
    wire [15:0] final_pixel = (!lcd_de) ? 16'h0000 : (show_bar ? color_bar_data : text_data);
    assign lcd_r = final_pixel[15:11];
    assign lcd_g = final_pixel[10:5];
    assign lcd_b = final_pixel[4:0];

endmodule