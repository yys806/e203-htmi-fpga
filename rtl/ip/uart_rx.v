module uart_rx(
    input  wire       clk,       // 27MHz
    input  wire       rx_pin,    // 物理接收引脚
    output reg  [7:0] data,      // 接收到的字节
    output reg        valid      // 收到一个字节时，产生一个脉冲
);

    // 波特率计算: 27,000,000 / 115200 ≈ 234
    localparam CNT_MAX = 156.25; 

    reg [7:0] cnt;
    reg [3:0] bit_idx;
    reg [1:0] state; // 0:Idle, 1:Start, 2:Data, 3:Stop
    reg       rx_d1, rx_d2; // 打两拍消除亚稳态

    always @(posedge clk) begin
        rx_d1 <= rx_pin;
        rx_d2 <= rx_d1;
    end

    always @(posedge clk) begin
        valid <= 0; // 默认无效
        
        case(state)
            0: begin // Idle
                if (rx_d2 == 0) begin // 检测到起始位(低电平)
                    state <= 1;
                    cnt   <= CNT_MAX / 2; // 从中间开始采样
                end
            end
            1: begin // Start bit check
                if (cnt > 0) cnt <= cnt - 1;
                else begin
                    cnt <= CNT_MAX;
                    state <= 2;
                    bit_idx <= 0;
                end
            end
            2: begin // Data bits (0-7)
                if (cnt > 0) cnt <= cnt - 1;
                else begin
                    cnt <= CNT_MAX;
                    data[bit_idx] <= rx_d2; // 采样数据
                    if (bit_idx == 7) state <= 3;
                    else bit_idx <= bit_idx + 1;
                end
            end
            3: begin // Stop bit
                if (cnt > 0) cnt <= cnt - 1;
                else begin
                    valid <= 1; // 【关键】告诉外部收到数据了
                    state <= 0;
                end
            end
        endcase
    end
endmodule