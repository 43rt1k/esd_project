// memory.c
#include <stdio.h>
#include "memory.h"

#define NIOS_INSTR "l.nios_rrr"

void DMA_init() {
  // Initialize DMA settings if needed
  // This function can be used to set up any initial configurations for DMA
  asm_DMA_W(DMA_BLOCK_SIZE, DMA_USED_BLOCK_SIZE); // Set DMA block size
  asm_DMA_W(DMA_BURST_SIZE, DMA_USED_BURST_SIZE); // Set DMA burst size
}

uint32_t DMA_p_inc(uint32_t p) {
  // Increment pointer by the size of a word in bytes
  return p + DMA_USED_BLOCK_SIZE * WORD_SIZE_BYTES;
}


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

void asm_DMA_wait_end() {
  uint32_t status;

  do {
    printf("Waiting for DMA to complete...\n");
    asm_DMA_R(&status, DMA_STATUS_R);
  } while (status != 0);
}