// memory.c
#include "memory.h"

#define NIOS_INSTR "l.nios_rrr"

void asm_DMA_W(uint32_t _in1, uint32_t _in2) {
  asm volatile(NIOS_INSTR " r0,%[in1],%[in2]," CI_ID_DMA 
                :
                : [in1] "r"(_in1 | DMA_W_BIT),
                  [in2] "r"(_in2));
}

void asm_DMA_R(uint32_t *_out1, uint32_t _in1) {
  asm volatile(NIOS_INSTR " %[out1],%[in1],r0," CI_ID_DMA 
                : [out1] "=r" (*_out1)
                : [in1] "r" (_in1));
}

void asm_DMA_wait_end(uint32_t* status) {
  do {
    asm_DMA_R(status, DMA_STATUS_CONTROL);
  } while (*status != 0);
}