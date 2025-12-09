# 项目报告：基于 RISC-V E203 的字符终端（HDMI + UART）

## 摘要（中文）
本项目在蜂鸟 E203 的 ICB 总线上挂接自定义字符终端外设，实现 640×480@60Hz HDMI/LCD 显示，上电 5 秒彩条自检后进入文本模式。通过板载 USB-JTAG 的 UART（115200 8N1，3.3V）接收 ASCII 数据并显示，支持提示符、回车换行、退格删除、自动换行，满足课程基本要求并覆盖扩展任务 3 的核心行为。核心模块包括 UART 接收、字符 FIFO、VRAM 文本帧缓冲、8×16 字库、显示时序、ICB 寄存器映射与中断。报告给出接口、实现细节、仿真要点、硬件测试流程与设计权衡。

## Abstract (English)
This project adds a custom terminal peripheral on the E203 ICB bus to drive HDMI/LCD at 640×480@60Hz. A 5-second color bar splash is shown on power-up, then a text mode with a prompt. ASCII characters are received via the on-board USB-JTAG UART (115200 8N1, 3.3V) and rendered as monochrome text. The design supports CR/LF, backspace, auto-wrap, and prompt output, meeting course requirements and covering the key behavior of extension task 3. Core blocks include UART RX, a small character FIFO, a VRAM text buffer, an 8×16 font, video timing, an ICB register map, and interrupt handling. Interfaces, implementation details, simulation guidance, hardware validation, and design trade-offs are presented.

## 关键词 / Keywords
RISC-V；E203；ICB；HDMI/LCD；UART；字符终端；640×480@60Hz；Tang Primer 20K；Gowin GW2A-18

## 1 引言
蜂鸟 E203 参考工程提供 ICB 总线与基础外设。为满足大作业“字符终端”要求，本设计在 ICB 槽 o5 上挂接自定义外设，利用 Tang Primer 20K + Dock 的 HDMI/LCD 与板载 USB-JTAG UART 资源，实现彩条自检、640×480 字符显示和串口输入显示，并完成扩展任务 3 的终端式行为（提示符、自动换行、退格）。

## 2 系统概述
- 处理器与总线：E203，终端外设挂在 ICB o5（默认基址 0x1001_4000）。
- 显示：640×480@60Hz，像素时钟约 18 MHz，彩条 5 秒后进入文本模式。
- 文本缓冲：VRAM 100×30 单色字符（3000 Byte），8×16 字库渲染，光标闪烁。
- 输入：板载 USB-JTAG UART（115200 8N1）复用 gpio_in[16] (T13)。
- 资源：GW2A-18，内部 SRAM 约 100KB，设计保持低占用与可收敛时序。

## 3 接口描述
### 3.1 ICB 寄存器（默认基址 0x1001_4000）
- 0x000 ID (R)：0x46505431。
- 0x004 STATUS (R)：`[15:8] fifo_data`，`[0] fifo_valid`，`[16] bar_active`，`[23] ctrl_irq_en`。
- 0x008 RXPOP (R)：弹出 FIFO 顶元素（空则 0）。
- 0x00C CTRL (R/W)：`[1] auto_inc`，`[2] irq_en`，`[0] clear=1` 触发清屏。
- 0x010 CURSOR (R/W)：`cursor_y[12:8], cursor_x[6:0]`。
- 0x014 VADDR (R/W)：VRAM 地址 0~2999。
- 0x018 VWDATA (W)：写 VRAM 字符，auto_inc 可自增。
- 0x01C VRDATA (R)：读 VRAM 字符。
- 0x020 CHARIN (W)：软件注入字符到 RX FIFO。
- 0x024 IRQSTS (R/W1C)：bit0 irq_pending，写 1 清除。

### 3.2 其他接口
- 中断：`io_interrupts_0_0`，FIFO 非空且 irq_en=1 置位。
- 时钟/复位：`clk`（外设/系统时钟，内部生成 pclk≈18 MHz），`rst_n` 低有效。
- UART：`term_uart_rx` 复用 gpio_in[16] (T13)，115200 8N1，3.3V。
- 显示（RGB565）：`lcd_dclk, lcd_hs, lcd_vs, lcd_de, lcd_bl, lcd_r[4:0], lcd_g[5:0], lcd_b[4:0]`。
- 管脚：见 `gowin_prj/e203_basic_chip.cst`，`lcd_r[2]` 改到 M9，保留 GPIO in/out，UART RX 用 T13。

## 4 核心模块的详细实现
- `fpga_terminal_icb.v`：ICB 读写、IRQ 管理、寄存器映射；RX FIFO（4 深度）请求-确认弹出，状态机（彩条→信息行→清屏→提示符→空闲接收），支持 CR/LF、Backspace/Delete、行末自动换行，提示符长度 17。
- `uart_rx.v`：115200 8N1，计数器过采样，双拍同步去亚稳，起始位居中采样。
- `video_ram.v`：字符 RAM（写口 + 多读口），新增 `r_addr_6/r_data_6` 供 CSR 读。
- `text_display.v`：坐标到点阵映射，调用 `font_rom` 8×16，叠加光标闪烁。
- `font_rom.v`：内置 ASCII 8×16 字库。
- `lcd_driver.v`：640×480 Timing 输出 `(x,y)` 与同步信号，像素时钟为 pclk。

## 5 仿真波形（说明）
- ICB：读 STATUS、RXPOP、写 CTRL(clear)、写 VADDR/VWDATA、读 VRDATA，验证 `rsp_valid/rsp_rdata`。
- UART：注入 115200 帧，观察 `valid` 脉冲与 `data` 对齐。
- FIFO 弹出：`pop_req`→`pop_ack`→`fifo_pop`，确认单次请求只弹一次。
- 状态机：`state` INIT→SHOW_INFO→WAIT_READ→CLEAR_ALL→PROMPT→IDLE，`write_en/write_addr/write_data` 簇写信息行与清屏。
- VRAM：写入与显示读口 `r_addr_0/r_data_0` 一致，字符位置正确。
- 截图占位（UART 帧示例，`term_uart_rx` 发送 “A”）：  
  ![UART A frame](TODO_UART_FRAME.png)

## 6 硬件测试方法和流程
1) 软件：进入 `firmware/hello_world`（或自定义应用）`make clean && make` 生成 `ram.hex`。
2) 工程：确保 `ram.hex` 已用于 ROM 初始化。
3) 综合/P&R：器件 `GW2A-18`，检查管脚；Dual-Purpose Pin 保持 JTAG/MSPI 默认，SSPI 未用可关。
4) 生成 bit/FS：Gowin IDE 导出。
5) 烧录：USB-JTAG 连接，Gowin Programmer/openFPGALoader 下载。
6) 运行验证：
   - 串口：选择 UART COM（非 JTAG COM），115200 8N1。
   - 现象：彩条→两行信息→清屏→提示符。
   - 功能：输入字符、换行、退格；读 STATUS/IRQSTS 验证 FIFO 非空与中断清除。

## 7 关键模块说明与设计权衡
- 终端状态机：计时 5s 彩条，批量写信息行，再清屏与提示符，空闲轮询 FIFO 写 VRAM。
- 弹出握手：`pop_req` 仅 FSM 驱动，寄存器侧检测后弹出并 `pop_ack`，FSM 见到确认清零，解决多倍/两倍显示。
- 光标/行宽：100×30，行末回行；CR/LF 统一换行；Backspace 不越过提示符；满屏循环回顶。
- 资源：3000B VRAM + 字库 ROM，像素时钟降到 ~18 MHz 便于时序收敛，满足 GW2A-18 SRAM 预算。
- 中断：FIFO 非空触发，写 IRQSTS 清除；支持轮询或中断驱动。

## 8 扩展任务 3（Linux 终端模拟）原理
- 已实现：提示符、逐字回显、CR/LF 换行、Backspace 删除、行满回行、循环滚动、终端样式显示。
- 原理：UART/FIFO 缓冲 → 终端 FSM 消费并写 VRAM → 字库渲染 → HDMI/LCD 显示。光标与提示符保证交互类似简化终端；未实现 ANSI 复杂控制码，若扩展可加入滚屏缓冲与 ESC 解析。

## 9 结论
设计在 E203 ICB 上完成字符终端挂接，实现 640×480 显示、彩条自检、UART 输入与终端式交互，满足基本要求并覆盖扩展任务 3 的核心行为。通过精简 FIFO/VRAM/字库与降低像素时钟，保证 GW2A-18 上的时序与布线可收敛。后续可在资源允许的情况下加入 ANSI 控制码与更高分辨率。

## 10 参考文献
1. `ref/` 目录资料与 Tang Primer 20K 示例项目。
2. Tang Primer 20K 原理图：`Tang_Primer_20K_SOM-3961_Schematic.pdf`、`Tang_Primer_20K_Dock-3713_Schematics.pdf`。
3. Sipeed 官方示例：https://github.com/sipeed/TangPrimer-20K-example
4. 课程提供的 E203 参考代码与 ICB 总线文档。
