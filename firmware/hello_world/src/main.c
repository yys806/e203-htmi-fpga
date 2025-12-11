/*
 ============================================================================
 Name        : main.c
 Author      : 
 Version     :
 Copyright   : Your copyright notice
 Description : Hello RISC-V World in C
 ============================================================================
 */

#include <stdint.h>
#include <platform.h>
#include "init.h"

// Terminal register helper
#define TERM_REG(off)    TERMINAL_REG(off)

static inline void term_write_char(uint8_t c) {
    TERM_REG(TERM_REG_CHARIN) = c;
}

static inline int term_pop_char(uint8_t *c) {
    uint32_t v = TERM_REG(TERM_REG_RXPOP);
    if (v & 0xFF) {
        *c = (uint8_t)(v & 0xFF);
        return 1;
    }
    return 0;
}

static void term_print(const char *s) {
    while (*s) {
        term_write_char((uint8_t)*s++);
    }
}

static void short_delay(void) {
    for (volatile uint32_t i = 0; i < 500000; i++) {
        __asm__ volatile("nop");
    }
}

int main(void) {
    _init();

    // 等待硬件彩条/信息阶段结束（简单延时，不清屏，不改光标）
    short_delay();

    // 软件提示
    term_print("SW echo ready\r\n");

    // 简易回显：从终端 FIFO 读出再写回
    while (1) {
        uint8_t ch;
        if (term_pop_char(&ch)) {
            term_write_char(ch);
        }
    }
    return 0;
}
