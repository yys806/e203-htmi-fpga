# 基于 RISC-V E203 的字符终端（HDMI + UART）

面向 Tang Primer 20K（GW2A-18）与 Dock 底板的课程大作业：在蜂鸟 E203 的 ICB 总线上挂接自定义终端外设，输出 HDMI（RGB565）显示彩条与黑白字符，并从 UART 接收 ASCII 数据显示。

## 功能概述
- 上电后 5 秒彩条显示；随后进入文本模式，默认在屏幕显示提示信息并出现命令行提示符 `root@shen_kai:# `。
- 支持 640×480 @60Hz（像素时钟约 18 MHz），字符缓冲 100×30（3000 字节 VRAM，单色）。
- 从 UART（115200 8N1，3.3 V，使用板载 USB-JTAG 的 UART 口）接收 ASCII 字符并显示，支持回车换行、退格与光标自动换行。
- ICB 外设寄存器可读写 VRAM、清屏、读 FIFO 等，支持软件注入字符与中断。

## 目录结构
- `rtl/ip/fpga_terminal_icb.v`：终端顶层，ICB 外设封装、UART RX、字符消费状态机、光标/清屏逻辑。
- `rtl/ip/text_display.v`：字符到点阵的取字渲染。
- `rtl/ip/font_rom.v`：内置 8×16 ASCII 字库。
- `rtl/ip/video_ram.v`：双口字符 RAM，增加 `r_addr_6/r_data_6` 供 CSR 读。
- `rtl/ip/lcd_driver.v`：640×480 Timing 产生与像素坐标输出。
- `rtl/ip/uart_rx.v`：简易 UART 接收，115200 8N1（计数常数按 ~50 MHz/27 MHz 时钟配置）。
- `gowin_prj/e203_basic_chip.cst`：已更新的引脚约束（LCD & UART）。
- `firmware`：E203 演示软件（需生成 `ram.hex` 后用于 FPGA 工程）。
- 其余 `rtl/core`、`rtl/perips` 等为老师提供的 E203 参考代码。

## 硬件连接与引脚
- 板卡：Tang Primer 20K + Dock，供电与下载：USB-JTAG 线连接 PC。
- 串口：同一 USB 会枚举出两个 COM 口，其中一个是 UART（115200 8N1，3.3 V）。无需额外飞线，使用 `gpio_in[16]`（T13）作为终端 RX。
- 主要 LCD/HDMI（RGB565）信号（详见 `gowin_prj/e203_basic_chip.cst`）：
  - `lcd_dclk R9`, `lcd_hs A15`, `lcd_vs D14`, `lcd_de E15`
  - `lcd_r[4:0] L9 N8 N9 N7 N6`（`lcd_r[2]` 已换到可用空闲管脚 M9，避免占用 SSPI）
  - `lcd_g[5:0] D11 A11 B11 P7 R7 D10`
  - `lcd_b[4:0] B12 C12 B13 A14 B14`
- 保留 GPIO in/out 功能：`gpio_in[16]` 同时作为终端 UART RX；GPIO 端口保持原有映射。

## 时钟与显示参数
- 基准时钟：板载 27 MHz。
- PLL 设备型号：设为 `GW2A-18`（避免 GW2A-55 的警告）。
- 像素时钟：约 18 MHz（在 `clk_unit` 内生成，用于 640×480@60Hz）。
- 彩条显示时间：约 5 秒（基于像素时钟计数）。

## ICB 寄存器映射（默认基址挂在外设槽 o5，可在顶层地址映射确认，一般为 `0x1001_4000`）
| 偏移 | 访问 | 说明 |
| ---- | ---- | ---- |
| 0x000 | R | ID，固定 `0x46505431` (“FPT1”) |
| 0x004 | R | STATUS：`[31:25]0, ctrl_irq_en, [23:17]0, bar_active, [15:9]0, fifo_data(8b), fifo_valid(1b)` |
| 0x008 | R | RXPOP：读出 FIFO 顶元素并弹出（若空返回 0） |
| 0x00C | R/W | CTRL：`[1]auto_inc`（VRAM 地址自增），`[2]irq_en`，`[0]clear` 置位触发清屏 |
| 0x010 | R/W | CURSOR：`cursor_y[12:8], cursor_x[6:0]` |
| 0x014 | R/W | VADDR：VRAM 访问地址（0~2999） |
| 0x018 | W | VWDATA：写 VRAM 数据（ASCII），可选自增 |
| 0x01C | R | VRDATA：读 VRAM 数据（复用内部端口） |
| 0x020 | W | CHARIN：软件注入单字节到 RX FIFO |
| 0x024 | R/W | IRQSTS：bit0 为 IRQ pending，写 1 清除 |

## 终端行为
- 上电：彩条 5s → 显示两行项目署名 → 清屏 → 输出提示符。
- 接收：UART / `CHARIN` 填充 FIFO，终端状态机逐字弹出并显示。
- 控制字符：CR/LF 换行；Backspace/Delete 支持删除；打印字符范围 0x20~0x7E。
- 中断：FIFO 非空且 IRQ 使能时置位 `irq_pending`，需软件读/清。

## 构建与烧录流程（Linux 环境）
1. **生成软件镜像**：进入 `firmware/hello_world`（或你的应用目录）运行 `make clean && make`，得到 `ram.hex`（或同名 HEX 文件）。若有自定义应用，请保持链接脚本与基址一致。
2. **更新 FPGA 工程**：在 Gowin IDE 打开 `gowin_prj` 工程，确保 `ram.hex` 已被包含/更新到初始化 ROM（若使用顶层脚本自动拷贝，请确认路径）。
3. **综合 & P&R**：目标器件选择 `GW2A-18`，若使用特殊管脚需在 “Dual-Purpose Pin” 中开启必要复用（JTAG 保持，MSPI/JTAG 默认保持即可；SSPI 未用时可保持关闭）。
4. **生成 bit/FS 文件**：完成 P&R 后导出 bitstream/FS。
5. **烧录**：通过 USB-JTAG 使用 Gowin Programmer 或 openFPGALoader（需支持 GW2A）烧录。

## 运行与验证步骤
1. USB 连接板卡，系统出现两个 COM 口，选择 UART 口（非 JTAG 口），串口参数 115200 8N1。
2. 上电/复位后观察屏幕：彩条 → 署名信息 → 清屏并出现提示符。
3. 在串口终端输入 ASCII 字符，屏幕应逐字显示；回车换行生效，退格删除有效。
4. 若字符异常：检查串口波特率/8N1、确保只打开一个串口终端，确认 GPIO16(T13) 未被其他逻辑占用。

## 测试与仿真建议
- **硬件快速检查**：仅接 USB-JTAG，即可同时供电、下载、UART 调试；确保使用正确的 COM 口。
- **功能自检**：查看彩条与提示符；输入一串已知字符（如 `ABCabc123!?`）验证无重复/丢字。
- **进一步仿真**（可选）：在 `sim` 目录复用老师提供的系统仿真脚本，重点观察 ICB 读写 `ADDR_RXPOP/ADDR_VWDATA`、UART RX 波形与 VRAM 显示地址。

## 参考资料
- `ref/` 目录下参考文献与 Tang Primer 20K 示例项目。
- `Tang_Primer_20K_SOM-3961_Schematic.pdf` 与 `Tang_Primer_20K_Dock-3713_Schematics.pdf`（引脚/电源/USB-JTAG UART）。
- 官方例程：https://github.com/sipeed/TangPrimer-20K-example（作业参考）。
