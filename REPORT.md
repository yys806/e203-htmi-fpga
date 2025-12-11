# 基于 RISC-V E203 的字符终端（HDMI + UART）——项目报告

## 摘要（中文）
本项目在蜂鸟 E203 的 ICB 总线上挂接自定义字符终端外设，输出 640×480@60Hz 彩条与黑白字符，并通过板载 USB-JTAG 的 UART（115200 8N1，3.3V）接收 ASCII 数据。终端硬件完成彩条自检、提示信息显示，软件（main.c）在复位后输出提示并实现 UART 回显。报告给出接口描述、核心模块实现、仿真/硬件验证方法，并附关键代码段。

## Abstract (English)
A custom terminal peripheral is integrated on the E203 ICB bus to drive HDMI/LCD at 640×480@60Hz, showing a splash color bar and monochrome text. UART via on-board USB-JTAG (115200 8N1) receives ASCII characters. Hardware handles splash and prompt display; software (main.c) prints a prompt and echoes UART input. Interfaces, core implementation, verification, and key code snippets are presented.

## 关键词 / Keywords
RISC-V；E203；ICB；HDMI/LCD；UART；字符终端；640×480@60Hz；Tang Primer 20K；Gowin GW2A-18

## 1 引言
依托蜂鸟 E203 与 Tang Primer 20K + Dock，本设计在 ICB 槽 o5 挂接“字符终端”外设，完成彩条自检、640×480 文本显示与 UART 输入回显，满足大作业基本要求并实现软硬件结合（硬件自检 + 软件提示与回显）。

## 2 接口描述
- 总线：ICB，默认基址 0x1001_4000（槽 o5）。
- 寄存器偏移：ID(0x000)、STATUS(0x004)、RXPOP(0x008)、CTRL(0x00C)、CURSOR(0x010)、VADDR/VWDATA/VRDATA(0x014/0x018/0x01C)、CHARIN(0x020)、IRQSTS(0x024)。
- UART：`term_uart_rx` 复用 GPIO16 (T13)，115200 8N1，3.3V。
- 显示：RGB565，`lcd_*`，640×480@60Hz；`bar_active` 指示彩条阶段。
- 管脚：见 `gowin_prj/e203_basic_chip.cst`（`lcd_r[2]` 迁移至可用管脚，UART RX 用 T13）。

## 3 核心模块
- `fpga_terminal_icb.v`：ICB 外设包装，UART RX、FIFO、终端状态机，彩条→信息→清屏/提示符，字符写 VRAM，光标管理。
- `uart_rx.v`：115200 8N1 接收，过采样计数。
- `video_ram.v` + `text_display.v` + `font_rom.v`：字符 RAM、多读口、8×16 点阵渲染。
- `lcd_driver.v`：640×480 时序生成，输出 `(x,y)` 与同步信号。
- `main.c`（软件）：复位后短延时，打印 “SW echo ready\r\n”，轮询 RXPOP，写 CHARIN 回显。

## 4 关键代码（软件侧）
- 终端寄存器定义：`firmware/hello_world/src/bsp/hbird-e200/include/headers/devices/terminal.h`
```c
#define TERM_REG_ID       0x000
#define TERM_REG_STATUS   0x004
#define TERM_REG_RXPOP    0x008
#define TERM_REG_CTRL     0x00C
#define TERM_REG_CURSOR   0x010
#define TERM_REG_VADDR    0x014
#define TERM_REG_VWDATA   0x018
#define TERM_REG_VRDATA   0x01C
#define TERM_REG_CHARIN   0x020
#define TERM_REG_IRQSTS   0x024
```
- 平台宏：`platform.h`（终端基址复用 0x10014000，访问宏 `TERMINAL_REG`）。
- `main.c` 核心逻辑：
```c
_init();
short_delay();                    // 等待硬件彩条/信息完成
term_print("SW echo ready\r\n");
while (1) {                        // 轮询回显
  uint8_t ch;
  if (term_pop_char(&ch)) {
    term_write_char(ch);
  }
}
```

## 5 关键代码（硬件侧简述）
- 顶层实例：`rtl/ip/fpga_terminal_icb.v`（挂在 e203_subsys_perips.o5）
  - ICB 端口：`i_icb_cmd_valid/read/addr/wdata`、`i_icb_rsp_valid/rdata`、`io_interrupts`。
  - UART 接收：`uart_rx u_uart(.clk(pclk), .rx_pin(term_uart_rx), .data(hw_rx_data), .valid(hw_rx_valid));`
  - FIFO 弹出握手（单驱动，避免多重驱动）：  
    ```verilog
    if (pop_req && !fifo_empty) begin
      fifo_pop();
      pop_ack <= 1'b1;
    end
    ```
  - 终端状态机（彩条→信息→清屏→提示符→空闲），写 VRAM：  
    ```verilog
    if (char_avail) begin
      consume_char <= 1'b1;
      pop_req <= 1'b1;
      // CR/LF/BS/可打印字符处理，write_en/write_addr/write_data 更新
    end
    ```
  - 彩条指示：`bar_active = (state == S_INIT);`
- 显示管线：`lcd_driver` 生成 640×480 时序；`text_display` + `font_rom` 取字渲染，`video_ram` 双口读写字符。

### 硬件关键代码片段（节选）
- `rtl/ip/fpga_terminal_icb.v`：UART/FIFO/ICB 与状态机
```verilog
// UART 接收与 FIFO
uart_rx u_uart (
  .clk   (pclk),
  .rx_pin(term_uart_rx),
  .data  (hw_rx_data),
  .valid (hw_rx_valid)
);

// pop_ack 只在此处驱动，避免多重驱动
always @(posedge pclk or posedge reset) begin
  ...
  if (pop_req && !fifo_empty) begin
    fifo_pop();
    pop_ack <= 1'b1;
  end
  ...
end

// 终端状态机（彩条->信息->清屏->提示符->空闲）
always @(posedge pclk) begin
  write_en <= 1'b0;
  consume_char <= 1'b0;
  if (reset) begin
    state <= S_INIT;
    ...
  end else begin
    case(state)
      S_INIT:     if (timer_cnt < INIT_DELAY) timer_cnt <= timer_cnt + 1'b1; else state <= S_SHOW_INFO;
      S_SHOW_INFO: ... // 写项目信息
      S_WAIT_READ: ...
      S_CLEAR_ALL: ...
      S_PROMPT:   ... // 写提示符
      S_IDLE: begin
        if (char_avail) begin
          consume_char <= 1'b1;
          pop_req <= 1'b1;
          // CR/LF/BS/可打印字符处理，更新 cursor/write_en/write_addr/write_data
        end
      end
      default: state <= S_INIT;
    endcase
  end
end

assign bar_active = (state == S_INIT);
```

- `rtl/ip/uart_rx.v`：115200 8N1 解码
```verilog
localparam CNT_MAX = 156.25; // 27/50MHz -> 115200bps
always @(posedge clk) begin
  valid <= 0;
  case(state)
    0: if (rx_d2 == 0) begin state <= 1; cnt <= CNT_MAX/2; end
    1: if (cnt==0) begin cnt<=CNT_MAX; state<=2; bit_idx<=0; end else cnt<=cnt-1;
    2: if (cnt==0) begin cnt<=CNT_MAX; data[bit_idx]<=rx_d2; if(bit_idx==7) state<=3; else bit_idx++; end else cnt<=cnt-1;
    3: if (cnt==0) begin valid<=1; state<=0; end else cnt<=cnt-1;
  endcase
end
```

- `rtl/ip/video_ram.v`：字符 RAM 多读口（只摘显示与 CSR 读）
```verilog
always @(posedge clk) begin
  if (w_en) mem[w_addr] <= w_data;
  r_data_0 <= mem[r_addr_0];    // 显示读口
  r_data_6 <= mem[r_addr_6];    // CSR 读口
end
```

- `rtl/ip/text_display.v`：字库取字、光标闪烁
```verilog
// 字符到点阵：ascii_code -> font_rom -> pixel_on
assign char_addr = {ascii_code, pixel_y[3:0]};
assign pixel_on  = font_data[3'd7 - pixel_x[2:0]] | cursor_overlay;
```

## 5 验证方法
- 硬件：USB-JTAG 供电/下载/UART；上电观察彩条→信息→软件提示；串口 115200 8N1 输入字符，屏幕回显。
- 仿真：Icarus + GTKWave，关注 `i_icb_cmd_valid/read/addr/wdata`、`write_en/write_addr/write_data/cursor_x/cursor_y`、`term_uart_rx`、`bar_active` 等信号。

## 6 运行与文件
- 固件构建：Linux/WSL 进入 `firmware/hello_world` 执行 `make clean && make`，生成 `Debug/ram.hex`，并覆盖仿真/工程使用的 hex。
- FPGA：Gowin 工程引用最新 hex，综合/P&R，USB-JTAG 烧录。

## 7 仿真、演示与照片
- 仿真过程截图：`img/1-1.png`～`1-4.png`（脚本执行、GTKWAVE 层级）。
- 波形截图：`img/1.png`（UART 帧）、`img/2.png`（显示时序）、`img/3.png`（彩条→文本）。
- 演示视频：`https://pan.baidu.com/s/1yF1l8_YlUiyY_49Oy-yVkg?pwd=dwu7`（提取码：`dwu7`）。
- 运行照片：`img/彩条.jpg`、`img/信息打印.jpg`、`img/终端演示1.jpg`、`img/终端演示2.jpg`。

## 8 结论
硬件端完成彩条/信息显示与终端显示管线；软件端通过 ICB 寄存器输出提示并回显 UART 输入，实现软硬件结合。最新固件需在 Linux/WSL 编译，确保 hex 与仿真/工程同步，即可在仿真与上板观察终端功能。
