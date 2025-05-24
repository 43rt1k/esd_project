// memory.h
#ifndef MEMORY_H
#define MEMORY_H

#include <stdint.h>

#define IMAGE_SIZE            (640*480)
#define WORD_SIZE_BYTES       4
#define WORD_TO_BYTES_SHIFT   1

#define DMA_W_BIT_POS         9
#define DMA_CONTR_BIT_POS     10
#define DMA_W_BIT             (1 << DMA_W_BIT_POS)

#define DMA_BUS_START_ADDR    (1 << DMA_CONTR_BIT_POS)
#define DMA_MEM_START_ADDR    (2 << DMA_CONTR_BIT_POS)
#define DMA_BLOCK_SIZE        (3 << DMA_CONTR_BIT_POS)
#define DMA_BURST_SIZE        (4 << DMA_CONTR_BIT_POS)
#define DMA_STATUS_CONTROL    (5 << DMA_CONTR_BIT_POS)

#define DMA_USED_CIRAM_ADDR   50
#define DMA_USED_BLOCK_SIZE   256
#define DMA_USED_BURST_SIZE   31
#define DMA_TOTAL_BLOCKS      600

#define DMA_START_BUS_TO_MEM  1
#define DMA_START_MEM_TO_BUS  2

#ifndef CI_ID_DMA
#define CI_ID_DMA "0x14" 
#endif

void asm_DMA_W(uint32_t _in1, uint32_t _in2);
void asm_DMA_R(uint32_t *_out1, uint32_t _in1);
void asm_DMA_wait_end(uint32_t* status);

#endif // MEMORY_H
