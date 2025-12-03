// ICB-wrapped character terminal with simple UART RX and RGB output.
// Exposes register map at slot O5 (default base 0x1001_4000).

module fpga_terminal_icb (
    input                   clk,
    input                   rst_n,

    // ICB interface
    input                   i_icb_cmd_valid,
    output                  i_icb_cmd_ready,
    input  [31:0]           i_icb_cmd_addr,
    input                   i_icb_cmd_read,
    input  [31:0]           i_icb_cmd_wdata,

    output                  i_icb_rsp_valid,
    input                   i_icb_rsp_ready,
    output [31:0]           i_icb_rsp_rdata,

    output                  io_interrupts_0_0,

    // dedicated UART RX for terminal
    input                   term_uart_rx,

    // video outputs (RGB565 style)
    output                  lcd_dclk,
    output                  lcd_hs,
    output                  lcd_vs,
    output                  lcd_de,
    output                  lcd_bl,
    output [4:0]            lcd_r,
    output [5:0]            lcd_g,
    output [4:0]            lcd_b
);

    // ------------------------------------------------------------------------
    // Clock/reset
    wire pclk = clk;
    wire reset = ~rst_n;

    // ------------------------------------------------------------------------
    // RX FIFO for UART + software injection
    reg  [7:0] rx_fifo [0:3];
    reg  [1:0] rx_wptr;
    reg  [1:0] rx_rptr;
    reg  [2:0] rx_count;

    wire fifo_full  = (rx_count == 3'd4);
    wire fifo_empty = (rx_count == 3'd0);

    wire [7:0] fifo_rdata = rx_fifo[rx_rptr];

    // from UART receiver
    wire [7:0] hw_rx_data;
    wire       hw_rx_valid;
    uart_rx u_uart (
        .clk   (pclk),
        .rx_pin(term_uart_rx),
        .data  (hw_rx_data),
        .valid (hw_rx_valid)
    );

    // push helper
    task automatic fifo_push;
        input [7:0] din;
        begin
            if (!fifo_full) begin
                rx_fifo[rx_wptr] <= din;
                rx_wptr <= rx_wptr + 1'b1;
                rx_count <= rx_count + 1'b1;
            end
        end
    endtask

    // pop helper
    task automatic fifo_pop;
        begin
            if (!fifo_empty) begin
                rx_rptr <= rx_rptr + 1'b1;
                rx_count <= rx_count - 1'b1;
            end
        end
    endtask

    // ------------------------------------------------------------------------
    // Control/CSR registers
    reg        ctrl_auto_inc;
    reg        ctrl_irq_en;
    reg [11:0] csr_vram_addr;
    reg [6:0]  csr_cursor_x;
    reg [4:0]  csr_cursor_y;

    reg        irq_pending;

    // clear request triggers VRAM clear in display FSM
    reg        clear_request;

    // sync read data
    reg [31:0] rsp_rdata;
    reg        rsp_valid;

    assign i_icb_cmd_ready = 1'b1; // zero-wait
    assign i_icb_rsp_valid = rsp_valid;
    assign i_icb_rsp_rdata = rsp_rdata;

    localparam ADDR_ID     = 12'h000;
    localparam ADDR_STATUS = 12'h004;
    localparam ADDR_RXPOP  = 12'h008;
    localparam ADDR_CTRL   = 12'h00C;
    localparam ADDR_CURSOR = 12'h010;
    localparam ADDR_VADDR  = 12'h014;
    localparam ADDR_VWDATA = 12'h018;
    localparam ADDR_VRDATA = 12'h01C;
    localparam ADDR_CHARIN = 12'h020;
    localparam ADDR_IRQSTS = 12'h024;

    reg  csr_vram_we;
    reg  [7:0] csr_vram_wdata;
    reg  csr_vram_re;

    reg  csr_char_in_pulse;
    reg  [7:0] csr_char_in_data;
    reg  csr_rx_pop_pulse;

    always @(posedge pclk or posedge reset) begin
        if (reset) begin
            ctrl_auto_inc   <= 1'b1;
            ctrl_irq_en     <= 1'b1;
            csr_vram_addr   <= 12'd0;
            csr_cursor_x    <= 7'd0;
            csr_cursor_y    <= 5'd0;
            clear_request   <= 1'b0;
            rsp_valid       <= 1'b0;
            rsp_rdata       <= 32'd0;
            csr_vram_we     <= 1'b0;
            csr_vram_re     <= 1'b0;
            csr_char_in_pulse <= 1'b0;
            csr_char_in_data  <= 8'd0;
            csr_rx_pop_pulse  <= 1'b0;
            irq_pending     <= 1'b0;
            rx_wptr         <= 2'd0;
            rx_rptr         <= 2'd0;
            rx_count        <= 3'd0;
        end else begin
            // defaults
            rsp_valid         <= 1'b0;
            csr_vram_we       <= 1'b0;
            csr_vram_re       <= 1'b0;
            csr_char_in_pulse <= 1'b0;
            csr_rx_pop_pulse  <= 1'b0;
            clear_request     <= 1'b0;

            // hardware RX
            if (hw_rx_valid) begin
                fifo_push(hw_rx_data);
            end
            // software injected char (same clock domain)
            if (csr_char_in_pulse) begin
                fifo_push(csr_char_in_data);
            end

            // IRQ pending when FIFO not empty
            if (ctrl_irq_en && !fifo_empty)
                irq_pending <= 1'b1;
            else if (!ctrl_irq_en)
                irq_pending <= 1'b0;

            if (i_icb_cmd_valid && i_icb_cmd_ready) begin
                rsp_valid <= 1'b1;
                case (i_icb_cmd_addr[11:0])
                    ADDR_ID: begin
                        rsp_rdata <= 32'h4650_5431; // "FPT1"
                    end
                    ADDR_STATUS: begin
                        rsp_rdata <= {7'd0, ctrl_irq_en, 7'd0, bar_active, 7'd0, fifo_empty ? 8'h00 : fifo_rdata, fifo_empty ? 1'b0 : 1'b1};
                    end
                    ADDR_RXPOP: begin
                        rsp_rdata <= {24'd0, fifo_empty ? 8'h00 : fifo_rdata};
                        if (!fifo_empty) begin
                            fifo_pop();
                            irq_pending <= 1'b0;
                        end
                        csr_rx_pop_pulse <= 1'b1;
                    end
                    ADDR_CTRL: begin
                        if (i_icb_cmd_read)
                            rsp_rdata <= {29'd0, ctrl_irq_en, ctrl_auto_inc, 1'b0};
                        else begin
                            ctrl_auto_inc <= i_icb_cmd_wdata[1];
                            ctrl_irq_en   <= i_icb_cmd_wdata[2];
                            if (i_icb_cmd_wdata[0])
                                clear_request <= 1'b1;
                        end
                    end
                    ADDR_CURSOR: begin
                        if (i_icb_cmd_read)
                            rsp_rdata <= {19'd0, csr_cursor_y, 1'b0, csr_cursor_x};
                        else begin
                            csr_cursor_x <= i_icb_cmd_wdata[6:0];
                            csr_cursor_y <= i_icb_cmd_wdata[12:8];
                        end
                    end
                    ADDR_VADDR: begin
                        if (i_icb_cmd_read)
                            rsp_rdata <= {20'd0, csr_vram_addr};
                        else
                            csr_vram_addr <= i_icb_cmd_wdata[11:0];
                    end
                    ADDR_VWDATA: begin
                        csr_vram_we     <= 1'b1;
                        csr_vram_wdata  <= i_icb_cmd_wdata[7:0];
                        if (ctrl_auto_inc)
                            csr_vram_addr <= csr_vram_addr + 1'b1;
                        rsp_rdata <= 32'd0;
                    end
                    ADDR_VRDATA: begin
                        csr_vram_re <= 1'b1;
                        rsp_rdata <= {24'd0, vram_r_data_dbg};
                    end
                    ADDR_CHARIN: begin
                        csr_char_in_pulse <= 1'b1;
                        csr_char_in_data  <= i_icb_cmd_wdata[7:0];
                        rsp_rdata <= 32'd0;
                    end
                    ADDR_IRQSTS: begin
                        if (i_icb_cmd_read)
                            rsp_rdata <= {31'd0, irq_pending};
                        else if (i_icb_cmd_wdata[0])
                            irq_pending <= 1'b0;
                    end
                    default: rsp_rdata <= 32'd0;
                endcase
            end
        end
    end

    assign io_interrupts_0_0 = irq_pending;

    // ------------------------------------------------------------------------
    // Terminal display logic
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

    reg [6:0] cursor_x;
    reg [4:0] cursor_y;
    reg [11:0] write_addr;
    reg [7:0]  write_data;
    reg        write_en;
    reg [2:0]  state;
    localparam S_INIT = 0, S_SHOW_INFO = 1, S_WAIT_READ = 2, S_CLEAR_ALL = 3, S_PROMPT = 4, S_IDLE = 5;
    reg [11:0] process_cnt;
    reg [27:0] timer_cnt;

    // readback ports for pattern detection
    wire [7:0] char_at_cursor_minus_1, char_at_cursor_minus_2, char_at_cursor_minus_3, char_at_cursor_minus_4, char_at_cursor_minus_5;

    // show color bar for 5 seconds (assumes ~27MHz pixel clock)
    wire bar_active = (state == S_INIT);

    // character source: FIFO (UART or SW)
    wire char_avail = !fifo_empty;
    wire [7:0] char_data = fifo_rdata;
    reg  consume_char;

    always @(posedge pclk) begin
        write_en <= 1'b0;
        consume_char <= 1'b0;

        if (reset) begin
            state <= S_INIT;
            timer_cnt <= 0;
            process_cnt <= 0;
            cursor_x <= 0;
            cursor_y <= 0;
        end else begin
            // SW VRAM write has priority
            if (csr_vram_we) begin
                write_en <= 1'b1;
                write_addr <= csr_vram_addr;
                write_data <= csr_vram_wdata;
            end

            case(state)
                S_INIT: begin
                    if (timer_cnt < 28'd135_000_000) timer_cnt <= timer_cnt + 1'b1;
                    else begin
                        state <= S_SHOW_INFO;
                        process_cnt <= 0;
                        timer_cnt <= 0;
                    end
                end
                S_SHOW_INFO: begin
                    if (process_cnt < 25) begin
                        write_addr <= (12*100) + (37+process_cnt);
                        write_data <= str_line1[(24-process_cnt)*8 +: 8];
                        write_en <= 1'b1;
                        process_cnt <= process_cnt + 1'b1;
                    end else if (process_cnt < 68) begin
                        write_addr <= (14*100)+(28+(process_cnt-25));
                        write_data <= str_line2[(42-(process_cnt-25))*8 +: 8];
                        write_en <= 1'b1;
                        process_cnt <= process_cnt + 1'b1;
                    end else begin
                        state <= S_WAIT_READ;
                        timer_cnt <= 0;
                    end
                end
                S_WAIT_READ: begin
                    if (timer_cnt < 28'd135_000_000) timer_cnt <= timer_cnt + 1'b1;
                    else begin
                        state <= S_CLEAR_ALL;
                        process_cnt <= 0;
                    end
                end
                S_CLEAR_ALL: begin
                    if (process_cnt < 3000) begin
                        write_addr <= process_cnt;
                        write_data <= 8'h00;
                        write_en <= 1'b1;
                        process_cnt <= process_cnt + 1'b1;
                    end else begin
                        state <= S_PROMPT;
                        process_cnt <= 0;
                        cursor_x <= 0;
                        cursor_y <= 0;
                    end
                end
                S_PROMPT: begin
                    if (process_cnt < PROMPT_LEN) begin
                        write_addr <= (cursor_y*100)+cursor_x;
                        write_data <= get_prompt_char(process_cnt[4:0]);
                        write_en <= 1'b1;
                        cursor_x <= cursor_x + 1'b1;
                        process_cnt <= process_cnt + 1'b1;
                    end else begin
                        state <= S_IDLE;
                    end
                end
                S_IDLE: begin
                    if (clear_request) begin
                        state <= S_CLEAR_ALL;
                        process_cnt <= 0;
                    end else if (char_avail) begin
                        consume_char <= 1'b1;
                        if (char_data == 8'h0D || char_data == 8'h0A) begin
                            cursor_x <= 0;
                            if (cursor_y < 29) cursor_y <= cursor_y + 1'b1;
                            else cursor_y <= 0;
                            process_cnt <= 0;
                            state <= S_PROMPT;
                        end else if (char_data == 8'h08 || char_data == 8'h7F) begin
                            if (cursor_x > PROMPT_LEN) begin
                                cursor_x <= cursor_x - 1'b1;
                                write_addr <= (cursor_y * 100) + (cursor_x - 1);
                                write_data <= 8'h00;
                                write_en <= 1'b1;
                            end else if (cursor_x == 0 && cursor_y > 0) begin
                                cursor_y <= cursor_y - 1'b1;
                                cursor_x <= 7'd99;
                                write_addr <= ((cursor_y - 1) * 100) + 99;
                                write_data <= 8'h00;
                                write_en <= 1'b1;
                            end
                        end else if (char_data >= 8'h20 && char_data <= 8'h7E) begin
                            write_addr <= (cursor_y * 100) + cursor_x;
                            write_data <= char_data;
                            write_en <= 1'b1;
                            if (cursor_x < 99) cursor_x <= cursor_x + 1'b1;
                            else begin
                                cursor_x <= 0;
                                if (cursor_y < 29) cursor_y <= cursor_y + 1'b1;
                                else cursor_y <= 0;
                            end
                        end
                    end
                end
                default: state <= S_INIT;
            endcase

            // consume after state logic to allow pop in same cycle
            if (consume_char)
                fifo_pop();
        end
    end

    // ------------------------------------------------------------------------
    // VRAM + display pipeline
    wire [10:0] x;
    wire [9:0]  y;
    lcd_driver u_driver(
        .clk     (pclk),
        .rst_n   (rst_n),
        .lcd_hs  (lcd_hs),
        .lcd_vs  (lcd_vs),
        .lcd_de  (lcd_de),
        .pixel_x (x),
        .pixel_y (y)
    );

    wire [11:0] vram_r_addr_0;
    wire [7:0]  vram_r_data_0;
    wire [7:0]  vram_r_data_dbg;
    
    video_ram u_vram(
        .clk(pclk),
        .w_en(write_en),
        .w_addr(write_addr),
        .w_data(write_data),
        // display
        .r_addr_0(vram_r_addr_0),
        .r_data_0(vram_r_data_0),
        // pattern match
        .r_addr_1((cursor_y * 100) + cursor_x - 1), .r_data_1(char_at_cursor_minus_1),
        .r_addr_2((cursor_y * 100) + cursor_x - 2), .r_data_2(char_at_cursor_minus_2),
        .r_addr_3((cursor_y * 100) + cursor_x - 3), .r_data_3(char_at_cursor_minus_3),
        .r_addr_4((cursor_y * 100) + cursor_x - 4), .r_data_4(char_at_cursor_minus_4),
        .r_addr_5((cursor_y * 100) + cursor_x - 5), .r_data_5(char_at_cursor_minus_5),
        // CSR read (reuse port 5)
        .r_addr_6(csr_vram_addr),
        .r_data_6(vram_r_data_dbg)
    );
    
    reg [24:0] blink_cnt;
    always @(posedge pclk) blink_cnt <= blink_cnt + 1'b1;
    wire blink_en = blink_cnt[24] && (state == S_IDLE); 

    wire is_pixel_on;
    text_display u_text(
        .clk(pclk),
        .pixel_x(x),
        .pixel_y(y),
        .cursor_x(cursor_x),
        .cursor_y(cursor_y),
        .cursor_blink(blink_en),
        .vram_addr(vram_r_addr_0),
        .ascii_code(vram_r_data_0),
        .pixel_on(is_pixel_on)
    );

    assign lcd_dclk = pclk;
    assign lcd_bl   = 1'b1;

    wire [15:0] color_bar_data = (x<100)?16'hFFFF:(x<200)?16'hFFE0:(x<300)?16'h07FF:(x<400)?16'h07E0:(x<500)?16'hF81F:(x<600)?16'hF800:(x<700)?16'h001F:16'h0000;
    wire [15:0] text_data = is_pixel_on ? 16'hFFFF : 16'h0000; 
    wire [15:0] final_pixel = (!lcd_de) ? 16'h0000 : (bar_active ? color_bar_data : text_data);
    assign lcd_r = final_pixel[15:11];
    assign lcd_g = final_pixel[10:5];
    assign lcd_b = final_pixel[4:0];

endmodule
