#ifndef _TERMINAL__H
#define _TERMINAL__H

// Register offsets for fpga_terminal_icb (slot o5, default base 0x10014000)
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

#endif // _TERMINAL__H
