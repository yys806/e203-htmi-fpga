# 基于RISC-V&E203字符终端(HDMI+UART）项目报告

<center>2352396 禹尧珅 & 2351283 吴凯</center>


## 摘要
本项目面向智能芯片与系统实践大作业（见 ref/芯片大作业中文版要求.md）提出的“软硬件协同、自主外设、可视化演示”需求，基于蜂鸟 E203 在 ICB 总线上挂接自定义字符终端外设，目标是在 Tang Primer 20K + Dock 开发板上实现 800×480@60Hz HDMI/LCD 输出、上电彩条自检与 UART 文本终端。终端硬件在rtl/ip/fpga_terminal_icb.v 中封装 ICB 寄存器、UART RX、FIFO 与字符状态机，使用 lcd_driver.v + text_display.v + font_rom.v + video_ram.v 构成显示管线，板载 USB-JTAG 的 UART（115200 8N1，3.3V，GPIO16/T13）承载 ASCII 输入。软件侧在 firmware/hello_world 的 main.c 初始化后输出提示、轮询 RXPOP 并写 CHARIN 回显，实现硬件彩条/提示 + 软件交互的整机闭环。项目遵循 README.md 描述的引脚约束与构建流程，参考 ref/ichip2024_Design_of_HDMI_display_module_for_RISC-V.pdf 的 HDMI 时序与字库设计思路、ref/openocd_howto.md 的调试经验和 ref/e02_understand_example_soc.md 的 ICB 使用范式，在仿真（Icarus + GTKWave）和上板测试（USB-JTAG 供电/下载/串口）两条链路下完成验证。最终终端可稳定输出彩条、项目信息、提示符，并对 UART 输入做 CR/LF、退格和自动换行处理，仿真波形与硬件显示均与设计一致。

## Abstract
This project implements a custom character-terminal peripheral on the Hummingbird E203 SoC via the ICB bus to satisfy the course assignment (see ref/芯片大作业中文版要求.md) that requests a self-designed peripheral with both hardware and software interaction. Targeting the Tang Primer 20K (GW2A-18) with Dock, the terminal drives an HDMI/LCD output at 640×480@60Hz. Hardware, located in rtl/ip/fpga_terminal_icb.v, integrates the ICB register bank, UART RX, FIFO, and a character state machine; the display pipeline is built with lcd_driver.v, text_display.v, font_rom.v, and video_ram.v. UART input comes from the on-board USB-JTAG bridge (115200 8N1, 3.3V on GPIO16/T13). On the firmware side, firmware/hello_world/main.c initializes the chip, delays until the splash/prompt finishes, prints a software prompt, polls RXPOP, and writes characters back through CHARIN to echo input, forming a hardware splash + software interaction loop. The design follows pin constraints and build steps documented in README.md, and draws timing and font design references from ref/ichip2024_Design_of_HDMI_display_module_for_RISC-V.pdf, debugging practices from ref/openocd_howto.md, and ICB usage patterns from ref/e02_understand_example_soc.md. Both Icarus/GTKWave simulation and on-board testing (USB-JTAG for power/program/UART) confirm stable splash, project-info display, prompt rendering, and CR/LF/backspace/wrap handling, matching the intended behavior.

## 关键词
RISC-V；E203；ICB；HDMI/LCD；UART；字符终端；640×480@60Hz；Tang Primer 20K；Gowin GW2A-18

## 一、引言
课程大作业要求在给定的蜂鸟 E203 SoC 基础上，自主设计一类能与 CPU 交互的外设并完成仿真、综合、上板演示。相比常规 GPIO 或计时类外设，本项目选择“字符终端”这一方向：一方面，显示管线与 UART 输入天然结合，能够在屏幕端直接展示软硬件联动效果；另一方面，640×480@60Hz 的 HDMI/LCD 时序与字符渲染链路涵盖时钟、存储、状态机、接口协议等多个知识点，符合 ref/ichip2024_Design_of_HDMI_display_module_for_RISC-V.pdf 中强调的综合性训练目标。

硬件平台采用 Tang Primer 20K（GW2A-18）与 Dock 底板，输入基准时钟 27 MHz；彩条阶段大约 5 秒用于自检与屏幕确认，随后进入文本模式。ICB 总线槽位选择 o5，对应默认基址 0x1001_4000，并在 gowin_prj/e203_basic_chip.cst 中对 lcd_* 与 UART RX（GPIO16/T13）做了约束修改，使其避开被占用的管脚。软件部分复用 firmware/hello_world 工程，遵循 README.md 中的“make clean && make 生成 ram.hex、替换仿真/工程引用”的流程，以确保仿真与上板使用同一份固件镜像。

在总体目标上，终端需要实现：1）上电彩条自检与项目信息提示；2）进入字符模式，提供 100×30 单色字符缓冲；3）接受 UART（115200 8N1）输入，正确处理 CR/LF、退格、自动换行；4）支持 ICB 寄存器读写 VRAM、清屏、软件注入字符、中断；5）在仿真与硬件场景下均可重复验证。为便于团队复用，本报告在五个部分中详细记录设计思路、开发过程、实验结果与未来改进方向，并引用 ref/structure.md 所示的目录结构帮助读者定位代码。

## 二、开发过程
### 2.1 需求拆解与方案论证
根据 ref/芯片大作业中文版要求.md 的评分点，团队将需求拆解为“接口正确性、显示质量、交互完整性、验证充分性”四类。接口方面，ICB 寄存器需覆盖 ID/状态/光标/VRAM 读写/中断；显示方面需保证 640×480@60Hz 时序、彩条检验、100×30 字符映射；交互方面要支持 UART 输入及软件注入，且行为符合常见终端习惯；验证方面需给出仿真和上板的可重复步骤。参考 ref/e02_understand_example_soc.md 的外设模板和 ref/ichip2024_Design_of_HDMI_display_module_for_RISC-V.pdf 的显示案例，最终确定“ICB 包装 + UART/FIFO + 状态机 + 字符显示管线”的分层方案。
### 2.2 总体架构
硬件总体框架由四个部分组成：
1. ICB 接口与寄存器阵列：位于 fpga_terminal_icb.v，负责解码 ICB 访问、驱动 STATUS/CTRL/CURSOR/VADDR/VWDATA/VRDATA/CHARIN/IRQSTS；同时产生 io_interrupts。
2. 输入子系统：uart_rx.v 完成 115200 8N1 解码，输出 8bit 数据和 valid 信号；上层 FIFO 缓冲接收到的字符，支持 ICB RXPOP 和状态位查询。
3. 字符状态机与 VRAM：状态机负责彩条→项目信息→清屏→提示符→空闲处理；字符写入通过 video_ram.v 完成，VRAM 容量 3000 字节，支持显示读口和 CSR 读口，配合光标自增/手动定位。
4. 显示管线：lcd_driver.v 生成 640×480@60Hz 时序和 (x,y) 坐标；text_display.v 将坐标映射到字符位置并从 font_rom.v 取 8×16 点阵；RGB565 输出至屏幕。彩条阶段通过状态机控制 bar_active，在 text_display 层切换输出源。
软件侧在 firmware/hello_world/src 下完成：terminal.h 定义寄存器偏移，platform.h 将终端基址映射到 0x1001_4000，main.c 初始化后通过 term_print 输出软件提示，再以轮询方式实现 UART 回显。软件与硬件共同承担交互体验：硬件负责彩条和开机信息，软件负责提示符后的人机交互。
### 2.3 ICB 接口与寄存器设计
寄存器偏移严格与 README.md 保持一致，方便查阅与调试：
- 0x000 ID (R)：固定返回 0x46505431，用于外设识别。
- 0x004 STATUS (R)：[15:8] fifo_data，[0] fifo_valid，[16] bar_active，[23] ctrl_irq_en，便于软件在不弹出 FIFO 的情况下窥视数据。
- 0x008 RXPOP (R)：弹出 FIFO 顶元素，空则返回 0，硬件在弹出后自动更新 fifo_empty。
- 0x00C CTRL (R/W)：[0] clear 写 1 触发全屏清空并回到 (0,0)，[1] auto_inc 控制 VRAM 自增写入，[2] irq_en 打开 FIFO 非空中断。
- 0x010 CURSOR (R/W)：cursor_y[12:8], cursor_x[6:0]，与状态机共享光标坐标。
- 0x014/0x018/0x01C VADDR/VWDATA/VRDATA：VRAM 地址寄存器、写数据、读数据，配合 auto_inc 完成大块搬运。
- 0x020 CHARIN (W)：软件注入字符到 RX FIFO，便于软件自测或脚本批量写入。
- 0x024 IRQSTS (R/W1C)：bit0 表示 FIFO 非空中断待清，写 1 清零。

ICB 逻辑遵循 ref/e02_understand_example_soc.md 的握手模式，保证 cmd/rsp 时序、读写互斥，并通过 reset 将寄存器归零。io_interrupts 只有在 irq_en 打开且 FIFO 非空时才置位，软件可用 CLINT/PPLIC 路径进一步转发；同时 STATUS[16] 把 bar_active 暴露给软件，便于等待彩条结束。
### 2.4 显示时序与字符渲染
显示部分复用了 ref/ichip2024_Design_of_HDMI_display_module_for_RISC-V.pdf 里的 VGA/HDMI 时序计算思路：在 27 MHz 输入下经 PLL 得到约 18 MHz 像素时钟，生成 800×525 总像素（640×480 可视区）的时序。lcd_driver.v 输出 lcd_dclk/lcd_hs/lcd_vs/lcd_de 与 (pixel_x, pixel_y)，供 text_display.v 判断是否在有效区。字符分辨率 8×16，对应 100 列 × 30 行，video_ram.v 以字节存储 ASCII 码。

text_display.v 将 (pixel_x, pixel_y) 转换为 (char_x, char_y, row_in_char, col_in_char)，在 font_rom.v 中按照 {ascii_code, pixel_y[3:0]} 构造地址，读取 8bit 点阵，结合光标闪烁 cursor_overlay 后输出黑白像素。状态机在彩条阶段令 bar_active = 1，使 text_display 直接输出彩条；进入文本阶段后按 VRAM 内容渲染。VRAM 另有 r_data_6 读口供 ICB 读，方便软件遍历或校验。
### 2.5 UART 接收、FIFO 与终端状态机
UART 输入经 uart_rx.v 处理，采用过采样计数（27/50MHz -> 115200bps，CNT_MAX 约 156）检测起始位并按位采样，输出 8bit 数据与 valid。数据进入单时钟 FIFO，状态机使用 pop_req/pop_ack 保障弹出握手唯一驱动，避免多重驱动警告。终端状态机流程：
1. S_INIT：彩条倒计时，维持 bar_active=1，约 5 秒。
2. S_SHOW_INFO：向 VRAM 写项目名称/版本/串口参数等提示行，方便用户确认；参考 README.md 提示内容。
3. S_CLEAR_ALL：清屏并复位光标。
4. S_PROMPT：写入提示符 root@shen_kai:# ，将光标置于下一列。
5. S_IDLE：进入正常交互，若 FIFO 有数据则弹出，根据字符类型执行 CR/LF/退格/可打印写入，超行自动换行，满屏时回卷。

该流程兼顾“硬件自举 + 软件交互”两种体验，且与 ref/openocd_howto.md 中的串口调试建议一致：开机即显示提示，便于确认波特率和连线。
### 2.6 软件设计与接口调用
firmware/hello_world 中的 terminal.h 提供寄存器偏移，platform.h 将基址映射到 0x10014000。main.c 的核心逻辑为：
1. _init() 完成时钟/中断等初始化；
2. short_delay() 等待彩条与硬件提示结束（依赖 STATUS[16] 或固定延时）；
3. term_print("SW echo ready\r\n") 输出软件提示行；
4. 主循环中调用 term_pop_char(&ch) 轮询 RXPOP，当有数据时用 term_write_char(ch) 写入 CHARIN，实现回显。  

软件还保留了对 CTRL 的清屏操作、CURSOR 的手动定位，便于后续扩展（如显示菜单或图形）。由于终端本身能在硬件侧完成退格/换行逻辑，软件只需简单回显即可。
### 2.7 仿真方案
仿真目录 sim/iverilog-lnx 提供脚本 sim_run_sys_tb.sh，在 sys_tb_top.sv 中通过 gpio_in[16] 发送 UART 样例（默认 "ABC\r\n"）。仿真关注的信号包括：
- ICB 命令/响应：i_icb_cmd_valid/read/addr/wdata、i_icb_rsp_valid/rdata，确认寄存器解码与握手正确；
- FIFO/状态机：pop_req/pop_ack/fifo_empty/fifo_rdata/write_en/write_addr/write_data/cursor_x/cursor_y/state，验证字符写入与光标移动；
- 显示：lcd_dclk/lcd_hs/lcd_vs/lcd_de、bar_active，确认彩条到文本的切换时序；
- UART：term_uart_rx 波形与期望 8N1 对齐。

运行步骤与 README.md 一致：进入 sim/iverilog-lnx，执行 bash sim_run_sys_tb.sh 生成 wave.out，再 vvp wave.out 产出 waveout.vcd，最后用 GTKWave 查看。ref/ichip2024_Design_of_HDMI_display_module_for_RISC-V.pdf 中的时序截图可作为对照。
### 2.8 工程集成与约束
Gowin 工程位于 gowin_prj，主要关注：
- 约束文件 e203_basic_chip.cst 中，lcd_r[2] 调整到可用管脚（M9），UART RX 使用 T13，避免与 Dock 资源冲突；
- 器件选择 GW2A-18，PLL 设定与 27 MHz 输入匹配；
- Dual-Purpose Pin 保持 JTAG/MSPI 默认，SSPI 未用可关闭；
- 生成 bit/FS 时确保引用最新的 ram.hex（来自 firmware 构建），保持仿真与上板一致。
### 2.9 问题记录与解决
开发过程中遇到的关键问题与应对：
- **多重驱动告警**：早期 pop_ack 在两个 always 块驱动，综合时报多重驱动。通过集中在状态机内唯一驱动 pop_ack（见 fpga_terminal_icb.v）解决。
- **彩条退出时序**：彩条持续时间过短导致部分显示器未锁定。参考 ref/ichip2024_Design_of_HDMI_display_module_for_RISC-V.pdf 的做法，将 INIT_DELAY 设定到约 5 秒，保证屏幕稳定后再切换。
- **UART 可靠性**：串口连接经 USB-JTAG，若 PC 端同时打开 JTAG 终端会造成冲突。按照 ref/openocd_howto.md 的建议仅保留一个串口会话，并在 STATUS 中暴露 bar_active，软件可等待硬件完成后再交互。
- **VRAM 读写一致性**：仿真中发现软件批量写 VRAM 时自增未生效，原因是 auto_inc 位未置位。通过文档和示例函数强调 CTRL[1] 的使用，并在 term_print 中默认开启。


## 三、实验结果与结论
### 3.1 仿真结果
仿真在 Ubuntu/WSL 环境下进行，按 “编译 -> 运行 -> 波形查看” 三步：
- bash sim_run_sys_tb.sh：调用 Icarus 编译顶层与终端 IP，生成 wave.out；
- vvp wave.out：仿真产生 waveout.vcd，其中 UART 输入、状态机跳转、VRAM 写入均可观察；
- gtkwave waveout.vcd：加载信号分层，验证 bar_active 从 1 变 0、write_en 在字符到达时拉高、cursor_x/cursor_y 随 CR/LF/退格正确变化。

仿真过程截图如下：
（1）执行 bash sim_run_sys_tb.sh ：
![1-1.png](https://work-1321607658.cos.ap-guangzhou.myqcloud.com/1-1.png)
（2）执行 vvp wave.out 生成 VCD：
![1-2.png](https://work-1321607658.cos.ap-guangzhou.myqcloud.com/1-2.png) 
（3）运行 gtkwave waveout.vcd：  
![1-3.png](https://work-1321607658.cos.ap-guangzhou.myqcloud.com/1-3.png)
（4）GTKWave 层级展开示例：
![1-4.png](https://work-1321607658.cos.ap-guangzhou.myqcloud.com/1-4.png)


仿真波形说明：
（1）UART 帧（term_uart_rx 发送 “A”）：起始位=0，8 数据位 LSB→MSB（0x41），停止位=1，位宽≈8.68μs（115200bps）。
![1.png](https://work-1321607658.cos.ap-guangzhou.myqcloud.com/1.png)
（2）显示时序：lcd_dclk 连续方波；lcd_hs 为低脉冲（行同步，周期≈31.7μs）；lcd_de 低有效，长低脉冲对应行内有效区；lcd_vs 在本窗口高电平（帧同步低脉冲周期≈16.7ms，当前窗口未落入）。  
![2.png](https://work-1321607658.cos.ap-guangzhou.myqcloud.com/2.png)
（3）彩条→文本切换：bar_active 从 1→0，表明彩条结束进入文本模式，同时 lcd_hs/de/dclk 时序正常。  
![3.png](https://work-1321607658.cos.ap-guangzhou.myqcloud.com/3.png)

### 3.2 上板验证
硬件验证在 Tang Primer 20K + Dock 上完成，步骤与 README.md 的“运行与验证”一致：
1. firmware/hello_world 下执行 make clean && make 生成 Debug/ram.hex；
2. 确保 Gowin 工程引用最新 ram.hex，综合、P&R，并通过 USB-JTAG 烧录；
3. PC 端选择 UART 口（非 JTAG），115200 8N1 打开终端；
4. 上电后观察彩条约 5 秒，随后出现项目信息、提示符；
5. 输入 ABCabc123!? 等字符，检查显示、换行、退格、行满回卷是否符合预期；如需进一步定位，可在 STATUS 中读取 FIFO 状态或在 IRQ 模式下验证中断置位/清除。
照片与视频保持原有路径与样式：
- 演示视频：https://pan.baidu.com/s/1yF1l8_YlUiyY_49Oy-yVkg?pwd=dwu7
- 运行照片（img/）：

（1）上电彩条自检：
![彩条.jpg](https://work-1321607658.cos.ap-guangzhou.myqcloud.com/%E5%BD%A9%E6%9D%A1.jpg)
（2）信息打印（打印基础信息以及我们的学号）：
![信息打印.jpg](https://work-1321607658.cos.ap-guangzhou.myqcloud.com/%E4%BF%A1%E6%81%AF%E6%89%93%E5%8D%B0.jpg)
（3）UART 终端交互演示：
- 演示1：
![终端演示1.jpg](https://work-1321607658.cos.ap-guangzhou.myqcloud.com/%E7%BB%88%E7%AB%AF%E6%BC%94%E7%A4%BA1.jpg)
- 演示2：
![终端演示2.jpg](https://work-1321607658.cos.ap-guangzhou.myqcloud.com/%E7%BB%88%E7%AB%AF%E6%BC%94%E7%A4%BA2.jpg)
### 3.3 结果分析
- 功能覆盖：彩条、项目信息、提示符、UART 回显、CR/LF/退格、自动换行、屏幕回卷全部按设计工作；硬件与软件提示串联后用户体验连贯。
- 时序稳定性：在 27 MHz 输入、约 18 MHz 像素时钟下，屏幕无抖动、无黑屏，彩条持续时间足够，显示器锁定正常。bar_active 的导出方便在仿真与软件中同步阶段。
- 交互延迟：UART 115200bps 下字符显示无可见延迟；FIFO 处理及 VRAM 写入均在单个时钟域完成，未见丢字或重复。
- 可维护性：寄存器映射与 README.md、terminal.h 一致，ref/structure.md 中的目录结构便于新成员快速定位；仿真脚本与上板流程均可复现。
- 潜在不足：当前仅支持单色字符、单 UART 输入，未做字符属性、滚动区域或多语言字库；固件主循环使用轮询，未充分利用中断。

## 四、总结与展望
本项目实现了在蜂鸟 E203 ICB 总线上挂接自定义字符终端外设的完整链路：硬件侧完成 ICB 封装、UART/FIFO、字符状态机、VRAM 与显示管线；软件侧提供初始化、提示输出与 UART 回显；仿真和上板的证据（波形、照片、视频）均证明设计可行且稳定。相较初版示例外设，终端方案在可视化、交互性和文档化方面均有明显提升，也满足了课程对“软硬件结合、可验证”的要求。

后续可考虑的扩展方向：1）引入前景/背景色、闪烁等字符属性，并在 VRAM 中扩展属性位；2）支持可编程分辨率或双缓冲，兼容 800×600 等更高模式；3）加入 UART TX，实现全双工；4）提供简单的命令解析或菜单，使终端能直接配置 E203 或其他外设；5）在固件侧加入中断驱动或 DMA，降低 CPU 占用；6）依据 ref/ichip2024_Design_of_HDMI_display_module_for_RISC-V.pdf 的高阶章节，尝试加入硬件滚动、位图显示或图形混合功能。

## 五、任务分工与其他说明

在本次大作业中，2352396禹尧珅负责e203的挂载以及UART模拟终端的实现，2351283吴凯负责仿真波形，显示字库的搭建以及彩条显示功能的实现。本次作业耗时3.5周，过程中使用了AI辅助编程以及题目的解析辅助。

整体项目演示视频已上传至百度网盘，链接为：https://pan.baidu.com/s/1yF1l8_YlUiyY_49Oy-yVkg?pwd=dwu7

代码也已上传至github，链接为：https://github.com/yys806/e203-htmi-fpga.git