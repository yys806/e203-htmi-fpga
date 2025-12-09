`timescale 1ns/10ps
`define USING_IVERILOG

module sys_tb_top();

  reg  clk;
  reg  lfextclk;
  reg  rst_n;

  wire hfclk = clk;

  // GPIO 接到 SoC，bit16 复用为终端 UART RX
  reg  [31:0] gpio_in_tb;
  wire [31:0] gpio_out_tb;
  wire term_uart_rx;
  assign term_uart_rx = gpio_in_tb[16];

`ifdef USING_IVERILOG
  initial begin
    $dumpfile("waveout.vcd");
    // 控制 VCD 窗口，避免文件过大
    $dumpvars(0, sys_tb_top);
    $dumpoff;
    #100_000;    // 0.1ms 开始记录
    $dumpon;
    #5_900_000;  // 记录到约 6.0ms
    $dumpoff;
  end
`endif

`ifdef USING_VCS
  initial begin
    $fsdbDumpfile("test.fsdb");
    $fsdbDumpvars;
  end
`endif

  // 仿真总时长延长到 8ms，覆盖彩条结束与文本写入
  initial begin
    #8ms;
    $display("[TB] finished at %0t", $time);
    $finish;
  end

  initial begin
    clk        <= 0;
    lfextclk   <= 0;
    rst_n      <= 0;
    gpio_in_tb <= 32'hFFFF_FFFF; // 空闲高
    #320us rst_n <= 1;
  end

  always begin
     #18.52 clk <= ~clk;
  end

  always begin
     #33 lfextclk <= ~lfextclk;
  end

  // UART 发送到 SoC（115200bps，bit 时间约 8.68us）
  localparam int UART_BIT = 8680; // ns
  task send_uart_byte(input [7:0] b);
    integer i;
    begin
      gpio_in_tb[16] <= 1'b0; #UART_BIT;        // start
      for(i=0; i<8; i=i+1) begin
        gpio_in_tb[16] <= b[i]; #UART_BIT;      // data
      end
      gpio_in_tb[16] <= 1'b1; #UART_BIT;        // stop
    end
  endtask

  // 向终端发送示例数据
  initial begin
    #(400_000); // 等待复位后约400us
    send_uart_byte("A");
    send_uart_byte("B");
    send_uart_byte("C");
    send_uart_byte(8'h0D); // CR
    send_uart_byte(8'h0A); // LF
  end

  e203_soc_demo uut (
        .clk_in              (clk),  

        .tck                 (), 
        .tms                 (), 
        .tdi                 (), 
        .tdo                 (),  

        .gpio_in             (gpio_in_tb),
        .gpio_out            (gpio_out_tb),
        .qspi_in             (),
        .qspi_out            (),      
        .qspi_sck            (),  
        .qspi_cs             (),   

        .erstn               (rst_n), 

        .dbgmode0_n          (1'b1), 
        .dbgmode1_n          (1'b1),
        .dbgmode3_n          (1'b1),
  
        .bootrom_n           (1'b0), 
  
        .aon_pmu_dwakeup_n   (), 
        .aon_pmu_padrst      (),    
        .aon_pmu_vddpaden    () 
    );

  // 仿真加速：强制 PLL 锁定与时钟直连，避免 lock 低导致内部复位不释放
  initial begin
    force uut.clk_unit.lock = 1'b1;
    force uut.clk_unit.clkout_system = clk;
    force uut.clk_unit.clkout_rtc = lfextclk;
    force uut.reset_n = rst_n;
  end

endmodule
