module font_rom(
    input  wire [7:0] ascii,
    input  wire [3:0] row,
    output reg  [7:0] data
);
    always @(*) begin
        case(ascii)
            // --- 控制字符 ---
            8'h00: data = 8'h00; // NULL (全黑)
            8'h20: data = 8'h00; // 空格

            // --- 标点符号 & 数字 ---
            8'h21: case(row) 1:data=16; 2:data=16; 3:data=16; 4:data=16; 5:data=16; 6:data=16; 8:data=16; default:data=0; endcase // !
            8'h22: case(row) 1:data=36; 2:data=36; 3:data=36; default:data=0; endcase // "
            8'h23: case(row) 2:data=36; 3:data=36; 4:data=126; 5:data=36; 6:data=126; 7:data=36; 8:data=36; default:data=0; endcase // #
            8'h24: case(row) 1:data=8; 2:data=62; 3:data=64; 4:data=62; 5:data=2; 6:data=62; 7:data=8; default:data=0; endcase // $
            8'h25: case(row) 1:data=98; 2:data=100; 3:data=8; 4:data=16; 5:data=38; 6:data=70; default:data=0; endcase // %
            8'h26: case(row) 2:data=56; 3:data=68; 4:data=20; 5:data=84; 6:data=88; 7:data=36; default:data=0; endcase // &
            8'h27: case(row) 1:data=24; 2:data=24; 3:data=8; default:data=0; endcase // '
            8'h28: case(row) 1:data=4; 2:data=8; 3:data=16; 4:data=16; 5:data=16; 6:data=16; 7:data=16; 8:data=16; 9:data=8; 10:data=4; default:data=0; endcase // (
            8'h29: case(row) 1:data=32; 2:data=16; 3:data=8; 4:data=8; 5:data=8; 6:data=8; 7:data=8; 8:data=8; 9:data=16; 10:data=32; default:data=0; endcase // )
            8'h2A: case(row) 3:data=16; 4:data=84; 5:data=56; 6:data=84; 7:data=16; default:data=0; endcase // *
            8'h2B: case(row) 3:data=16; 4:data=16; 5:data=124; 6:data=16; 7:data=16; default:data=0; endcase // +
            8'h2C: case(row) 9:data=24; 10:data=24; 11:data=8; 12:data=16; default:data=0; endcase // ,
            8'h2D: case(row) 6:data=126; default:data=0; endcase // -
            8'h2E: case(row) 9:data=24; 10:data=24; default:data=0; endcase // .
            8'h2F: case(row) 2:data=2; 3:data=2; 4:data=4; 5:data=8; 6:data=16; 7:data=32; 8:data=64; 9:data=64; default:data=0; endcase // /
            
            8'h30: case(row) 1:data=60; 2:data=66; 3:data=66; 4:data=66; 5:data=66; 6:data=66; 7:data=66; 8:data=66; 9:data=60; default:data=0; endcase // 0
            8'h31: case(row) 1:data=8; 2:data=24; 3:data=8; 4:data=8; 5:data=8; 6:data=8; 7:data=8; 8:data=8; 9:data=28; default:data=0; endcase // 1
            8'h32: case(row) 1:data=60; 2:data=66; 3:data=2; 4:data=2; 5:data=60; 6:data=64; 7:data=64; 8:data=66; 9:data=126; default:data=0; endcase // 2
            8'h33: case(row) 1:data=60; 2:data=66; 3:data=2; 4:data=28; 5:data=2; 6:data=2; 7:data=66; 8:data=66; 9:data=60; default:data=0; endcase // 3
            8'h34: case(row) 1:data=4; 2:data=12; 3:data=20; 4:data=36; 5:data=68; 6:data=126; 7:data=4; 8:data=4; 9:data=4; default:data=0; endcase // 4
            8'h35: case(row) 1:data=126; 2:data=64; 3:data=64; 4:data=124; 5:data=2; 6:data=2; 7:data=2; 8:data=66; 9:data=60; default:data=0; endcase // 5
            8'h36: case(row) 1:data=60; 2:data=66; 3:data=64; 4:data=124; 5:data=66; 6:data=66; 7:data=66; 8:data=66; 9:data=60; default:data=0; endcase // 6
            8'h37: case(row) 1:data=126; 2:data=2; 3:data=4; 4:data=8; 5:data=8; 6:data=16; 7:data=16; 8:data=32; 9:data=32; default:data=0; endcase // 7
            8'h38: case(row) 1:data=60; 2:data=66; 3:data=66; 4:data=60; 5:data=66; 6:data=66; 7:data=66; 8:data=66; 9:data=60; default:data=0; endcase // 8
            8'h39: case(row) 1:data=60; 2:data=66; 3:data=66; 4:data=66; 5:data=62; 6:data=2; 7:data=66; 8:data=66; 9:data=60; default:data=0; endcase // 9
            
            8'h3A: case(row) 4:data=24; 5:data=24; 8:data=24; 9:data=24; default:data=0; endcase // :
            8'h3B: case(row) 4:data=24; 5:data=24; 8:data=24; 9:data=24; 10:data=8; 11:data=16; default:data=0; endcase // ;
            8'h3C: case(row) 3:data=6; 4:data=24; 5:data=96; 6:data=24; 7:data=6; default:data=0; endcase // <
            8'h3D: case(row) 4:data=126; 6:data=126; default:data=0; endcase // =
            8'h3E: case(row) 3:data=96; 4:data=24; 5:data=6; 6:data=24; 7:data=96; default:data=0; endcase // >
            8'h3F: case(row) 1:data=60; 2:data=66; 3:data=4; 4:data=8; 5:data=16; 6:data=16; 8:data=16; default:data=0; endcase // ?
            8'h40: case(row) 2:data=60; 3:data=66; 4:data=74; 5:data=86; 6:data=94; 7:data=64; 8:data=66; 9:data=60; default:data=0; endcase // @

            // --- 大写字母 A-Z ---
            8'h41: case(row) 1:data=24; 2:data=36; 3:data=66; 4:data=66; 5:data=126; 6:data=66; 7:data=66; 8:data=66; 9:data=66; default:data=0; endcase
            8'h42: case(row) 1:data=124; 2:data=66; 3:data=66; 4:data=66; 5:data=124; 6:data=66; 7:data=66; 8:data=66; 9:data=124; default:data=0; endcase
            8'h43: case(row) 1:data=60; 2:data=66; 3:data=64; 4:data=64; 5:data=64; 6:data=64; 7:data=64; 8:data=66; 9:data=60; default:data=0; endcase
            8'h44: case(row) 1:data=120; 2:data=68; 3:data=66; 4:data=66; 5:data=66; 6:data=66; 7:data=66; 8:data=68; 9:data=120; default:data=0; endcase
            8'h45: case(row) 1:data=126; 2:data=64; 3:data=64; 4:data=64; 5:data=120; 6:data=64; 7:data=64; 8:data=64; 9:data=126; default:data=0; endcase
            8'h46: case(row) 1:data=126; 2:data=64; 3:data=64; 4:data=64; 5:data=120; 6:data=64; 7:data=64; 8:data=64; 9:data=64; default:data=0; endcase
            8'h47: case(row) 1:data=60; 2:data=66; 3:data=64; 4:data=64; 5:data=64; 6:data=78; 7:data=66; 8:data=66; 9:data=62; default:data=0; endcase
            8'h48: case(row) 1:data=66; 2:data=66; 3:data=66; 4:data=66; 5:data=126; 6:data=66; 7:data=66; 8:data=66; 9:data=66; default:data=0; endcase
            8'h49: case(row) 1:data=60; 2:data=24; 3:data=24; 4:data=24; 5:data=24; 6:data=24; 7:data=24; 8:data=24; 9:data=60; default:data=0; endcase
            8'h4A: case(row) 1:data=6; 2:data=6; 3:data=6; 4:data=6; 5:data=6; 6:data=6; 7:data=66; 8:data=66; 9:data=60; default:data=0; endcase
            8'h4B: case(row) 1:data=66; 2:data=70; 3:data=74; 4:data=82; 5:data=98; 6:data=82; 7:data=74; 8:data=70; 9:data=66; default:data=0; endcase
            8'h4C: case(row) 1:data=64; 2:data=64; 3:data=64; 4:data=64; 5:data=64; 6:data=64; 7:data=64; 8:data=64; 9:data=126; default:data=0; endcase
            8'h4D: case(row) 1:data=66; 2:data=102; 3:data=90; 4:data=90; 5:data=82; 6:data=82; 7:data=82; 8:data=82; 9:data=82; default:data=0; endcase
            8'h4E: case(row) 1:data=66; 2:data=70; 3:data=74; 4:data=82; 5:data=82; 6:data=74; 7:data=74; 8:data=70; 9:data=66; default:data=0; endcase
            8'h4F: case(row) 1:data=60; 2:data=66; 3:data=66; 4:data=66; 5:data=66; 6:data=66; 7:data=66; 8:data=66; 9:data=60; default:data=0; endcase
            8'h50: case(row) 1:data=124; 2:data=66; 3:data=66; 4:data=66; 5:data=124; 6:data=64; 7:data=64; 8:data=64; 9:data=64; default:data=0; endcase
            8'h51: case(row) 1:data=60; 2:data=66; 3:data=66; 4:data=66; 5:data=66; 6:data=66; 7:data=74; 8:data=68; 9:data=62; default:data=0; endcase
            8'h52: case(row) 1:data=124; 2:data=66; 3:data=66; 4:data=66; 5:data=124; 6:data=72; 7:data=68; 8:data=66; 9:data=66; default:data=0; endcase
            8'h53: case(row) 1:data=60; 2:data=66; 3:data=64; 4:data=60; 5:data=2; 6:data=2; 7:data=66; 8:data=66; 9:data=60; default:data=0; endcase
            8'h54: case(row) 1:data=126; 2:data=24; 3:data=24; 4:data=24; 5:data=24; 6:data=24; 7:data=24; 8:data=24; 9:data=24; default:data=0; endcase
            8'h55: case(row) 1:data=66; 2:data=66; 3:data=66; 4:data=66; 5:data=66; 6:data=66; 7:data=66; 8:data=66; 9:data=60; default:data=0; endcase
            8'h56: case(row) 1:data=66; 2:data=66; 3:data=66; 4:data=66; 5:data=66; 6:data=66; 7:data=36; 8:data=36; 9:data=24; default:data=0; endcase
            8'h57: case(row) 1:data=66; 2:data=66; 3:data=66; 4:data=66; 5:data=82; 6:data=82; 7:data=90; 8:data=90; 9:data=66; default:data=0; endcase
            8'h58: case(row) 1:data=66; 2:data=66; 3:data=36; 4:data=24; 5:data=24; 6:data=36; 7:data=66; 8:data=66; 9:data=66; default:data=0; endcase
            8'h59: case(row) 1:data=66; 2:data=66; 3:data=36; 4:data=24; 5:data=24; 6:data=24; 7:data=24; 8:data=24; 9:data=24; default:data=0; endcase
            8'h5A: case(row) 1:data=126; 2:data=2; 3:data=4; 4:data=8; 5:data=16; 6:data=32; 7:data=64; 8:data=64; 9:data=126; default:data=0; endcase

            8'h5B: case(row) 1:data=60; 2:data=32; 3:data=32; 4:data=32; 5:data=32; 6:data=32; 7:data=32; 8:data=32; 9:data=60; default:data=0; endcase // [
            8'h5C: case(row) 2:data=64; 3:data=64; 4:data=32; 5:data=16; 6:data=8; 7:data=4; 8:data=2; 9:data=2; default:data=0; endcase // \
            8'h5D: case(row) 1:data=60; 2:data=4; 3:data=4; 4:data=4; 5:data=4; 6:data=4; 7:data=4; 8:data=4; 9:data=60; default:data=0; endcase // ]
            8'h5E: case(row) 2:data=24; 3:data=60; 4:data=102; default:data=0; endcase // ^
            8'h5F: case(row) 12:data=126; default:data=0; endcase // _
            
            // --- 小写字母 a-z ---
            8'h61: case(row) 4:data=60; 5:data=2; 6:data=62; 7:data=66; 8:data=66; 9:data=66; 10:data=62; default:data=0; endcase
            8'h62: case(row) 1:data=64; 2:data=64; 3:data=64; 4:data=92; 5:data=98; 6:data=66; 7:data=66; 8:data=66; 9:data=98; 10:data=92; default:data=0; endcase
            8'h63: case(row) 4:data=60; 5:data=66; 6:data=64; 7:data=64; 8:data=64; 9:data=66; 10:data=60; default:data=0; endcase
            8'h64: case(row) 1:data=2; 2:data=2; 3:data=2; 4:data=58; 5:data=70; 6:data=66; 7:data=66; 8:data=66; 9:data=70; 10:data=58; default:data=0; endcase
            8'h65: case(row) 4:data=60; 5:data=66; 6:data=66; 7:data=126; 8:data=64; 9:data=64; 10:data=60; default:data=0; endcase
            8'h66: case(row) 1:data=12; 2:data=18; 3:data=16; 4:data=60; 5:data=16; 6:data=16; 7:data=16; 8:data=16; 9:data=16; 10:data=16; default:data=0; endcase
            8'h67: case(row) 4:data=58; 5:data=70; 6:data=66; 7:data=66; 8:data=70; 9:data=58; 10:data=2; 11:data=60; default:data=0; endcase
            8'h68: case(row) 1:data=64; 2:data=64; 3:data=64; 4:data=92; 5:data=98; 6:data=66; 7:data=66; 8:data=66; 9:data=66; 10:data=66; default:data=0; endcase
            8'h69: case(row) 1:data=16; 3:data=48; 4:data=16; 5:data=16; 6:data=16; 7:data=16; 8:data=16; 9:data=16; 10:data=60; default:data=0; endcase
            8'h6A: case(row) 1:data=4; 3:data=12; 4:data=4; 5:data=4; 6:data=4; 7:data=4; 8:data=4; 9:data=4; 10:data=68; 11:data=56; default:data=0; endcase
            8'h6B: case(row) 1:data=64; 2:data=64; 3:data=64; 4:data=68; 5:data=72; 6:data=80; 7:data=96; 8:data=80; 9:data=72; 10:data=68; default:data=0; endcase
            8'h6C: case(row) 1:data=48; 2:data=16; 3:data=16; 4:data=16; 5:data=16; 6:data=16; 7:data=16; 8:data=16; 9:data=16; 10:data=60; default:data=0; endcase
            8'h6D: case(row) 4:data=106; 5:data=146; 6:data=146; 7:data=146; 8:data=146; 9:data=146; 10:data=146; default:data=0; endcase
            8'h6E: case(row) 4:data=92; 5:data=98; 6:data=66; 7:data=66; 8:data=66; 9:data=66; 10:data=66; default:data=0; endcase
            8'h6F: case(row) 4:data=60; 5:data=66; 6:data=66; 7:data=66; 8:data=66; 9:data=66; 10:data=60; default:data=0; endcase
            8'h70: case(row) 4:data=92; 5:data=98; 6:data=66; 7:data=66; 8:data=66; 9:data=98; 10:data=92; 11:data=64; default:data=0; endcase
            8'h71: case(row) 4:data=58; 5:data=70; 6:data=66; 7:data=66; 8:data=66; 9:data=70; 10:data=58; 11:data=2; default:data=0; endcase
            8'h72: case(row) 4:data=94; 5:data=96; 6:data=64; 7:data=64; 8:data=64; 9:data=64; 10:data=64; default:data=0; endcase
            8'h73: case(row) 4:data=60; 5:data=66; 6:data=64; 7:data=60; 8:data=2; 9:data=66; 10:data=60; default:data=0; endcase
            8'h74: case(row) 2:data=16; 3:data=16; 4:data=62; 5:data=16; 6:data=16; 7:data=16; 8:data=16; 9:data=18; 10:data=12; default:data=0; endcase
            8'h75: case(row) 4:data=66; 5:data=66; 6:data=66; 7:data=66; 8:data=66; 9:data=66; 10:data=58; default:data=0; endcase
            8'h76: case(row) 4:data=66; 5:data=66; 6:data=66; 7:data=36; 8:data=36; 9:data=24; 10:data=24; default:data=0; endcase
            8'h77: case(row) 4:data=66; 5:data=66; 6:data=66; 7:data=73; 8:data=73; 9:data=73; 10:data=54; default:data=0; endcase
            8'h78: case(row) 4:data=66; 5:data=36; 6:data=24; 7:data=24; 8:data=36; 9:data=66; 10:data=66; default:data=0; endcase
            8'h79: case(row) 4:data=66; 5:data=66; 6:data=66; 7:data=66; 8:data=60; 9:data=4; 10:data=60; default:data=0; endcase
            8'h7A: case(row) 4:data=126; 5:data=4; 6:data=8; 7:data=16; 8:data=32; 9:data=64; 10:data=126; default:data=0; endcase
            
            8'h7B: case(row) 1:data=12; 2:data=16; 3:data=16; 4:data=16; 5:data=48; 6:data=16; 7:data=16; 8:data=16; 9:data=12; default:data=0; endcase // {
            8'h7C: case(row) 1:data=16; 2:data=16; 3:data=16; 4:data=16; 5:data=16; 6:data=16; 7:data=16; 8:data=16; 9:data=16; 10:data=16; default:data=0; endcase // |
            8'h7D: case(row) 1:data=48; 2:data=8; 3:data=8; 4:data=8; 5:data=12; 6:data=8; 7:data=8; 8:data=8; 9:data=48; default:data=0; endcase // }
            8'h7E: case(row) 5:data=76; 6:data=50; default:data=0; endcase // ~

            default: data = (row==0 || row==15) ? 8'hFF : 8'h81; // 未定义字符显示方框
        endcase
    end
endmodule