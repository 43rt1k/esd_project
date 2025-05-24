#include <stdio.h>
#include "profiling.h"
#include "camera.h"
#include "gpio.h"
#include "memory.h"
#include "swap.h"

#define __WITH_DMA__

int main() {
    // Frame buffers
    volatile uint16_t rgb565[IMAGE_SIZE];
    volatile uint8_t grayScale[IMAGE_SIZE];
    volatile uint8_t blurBuffer[IMAGE_SIZE];   // Gaussian output
    volatile uint8_t sobelBuffer[IMAGE_SIZE];  // Sobel output

    // Peripherals
    volatile unsigned int* vga = (unsigned int*)0x50000020;
    volatile unsigned int* gpio = (unsigned int*)0x40000000;

    volatile uint32_t result;
    camParameters camParams;
    volatile ProfilingStatus profData;

    // Initialization
    cam_init(&camParams, (unsigned int*)vga, &result, sobelBuffer);
    asm_reset_profiling();
    #ifdef __WITH_DMA__  
    /* set up the generic dma parameters */
    asm_DMA_W(DMA_BLOCK_SIZE, DMA_USED_BLOCK_SIZE); // Set DMA block size
    asm_DMA_W(DMA_BURST_SIZE, DMA_USED_BURST_SIZE); // Set DMA burst size
    #endif

    uint32_t grayPixels;
    uint32_t pixel1, pixel2;

    while (1) {
        // Image capture
        takeSingleImageBlocking((uint32_t)&rgb565[0]);

        // DIP switch value to 7-segment
        uint32_t dipSwitch = gpio_get_DipSw(gpio);
        gpio_set_sevenSeg(gpio, dipSwitch);

        // Profiling start
        asm_enable_profiling_counters();


        #ifdef __WITH_DMA__

        uint32_t dmaBuffer = 0; // DMA buffer index
        uint32_t workBuffer = DMA_USED_BLOCK_SIZE; // Working buffer index
        uint32_t status; // DMA status
        uint32_t p_rgb = (uint32_t) &rgb565[0];
        uint32_t p_gray = (uint32_t) &grayScale[0];
        /* perform the first initial DMA */
        asm_DMA_W(DMA_BUS_START_ADDR, p_rgb); // Set DMA bus start address
        p_rgb += DMA_USED_BLOCK_SIZE * WORD_SIZE_BYTES; // Increment pointer
        asm_DMA_W(DMA_MEM_START_ADDR, dmaBuffer); // Set DMA memory start address
        asm_DMA_W(DMA_STATUS_CONTROL, DMA_START_BUS_TO_MEM); // Start DMA bus-to-memory transfer

        asm_DMA_wait_end(&status); // Wait for DMA transfer to complete

        for (int i = 0 ; i < DMA_TOTAL_BLOCKS; i++) {
        /* swap buffers */
        status = dmaBuffer; // Swap DMA buffers
        dmaBuffer = workBuffer;
        workBuffer = status;

        /* perform DMA in */
        if (i < (DMA_TOTAL_BLOCKS - 1)) {
            asm_DMA_W(DMA_BUS_START_ADDR, p_rgb); // Set DMA bus start address

            p_rgb += DMA_USED_BLOCK_SIZE * WORD_SIZE_BYTES; // Increment pointer

            asm_DMA_W(DMA_MEM_START_ADDR, dmaBuffer); // Set DMA memory start address
            
            asm_DMA_W(DMA_STATUS_CONTROL, DMA_START_BUS_TO_MEM); // Start DMA bus-to-memory transfer
        }

        /* perform transformation */
        for (uint16_t pixel = 0 ; pixel < DMA_USED_BLOCK_SIZE ; pixel += 2) {

            asm_DMA_R(&pixel1, workBuffer + pixel); // Read pixel1 from DMA buffer
            asm_DMA_R(&pixel2, workBuffer + pixel + 1); // Read pixel2 from DMA buffer

            pixel1 = swap_u32(pixel1); // Swap byte order of pixel1
            pixel2 = swap_u32(pixel2); // Swap byte order of pixel2

            grayPixels = asm_rgb_2_gray(pixel1, pixel2); // Convert RGB565 to grayscale
            grayPixels = swap_u32(grayPixels); // Swap byte order of grayscale pixels
            asm_DMA_W((workBuffer+(pixel>>1)), grayPixels); // Write grayscale pixels to DMA buffer
        }


        asm_DMA_wait_end(&status); // Wait for DMA transfer to complete

        /* perform DMA out */
        asm_DMA_W(DMA_BUS_START_ADDR, p_gray); // Set DMA bus start address

        p_gray += (DMA_USED_BLOCK_SIZE << WORD_TO_BYTES_SHIFT); // Increment pointer

        asm_DMA_W(DMA_BLOCK_SIZE, (DMA_USED_BLOCK_SIZE >> WORD_TO_BYTES_SHIFT)); // Set DMA block size
        asm_DMA_W(DMA_MEM_START_ADDR, workBuffer); // Set DMA memory start address
        asm_DMA_W(DMA_STATUS_CONTROL, DMA_START_MEM_TO_BUS); // Start DMA memory-to-bus transfer

        asm_DMA_wait_end(&status); // Wait for DMA transfer to complete
        
        asm_DMA_W(DMA_BLOCK_SIZE, DMA_USED_BLOCK_SIZE); // Reset DMA block size
        }
        #endif // __WITH_DMA__

        // RGB565 -> grayscale
        cam_rgb_2_gray(&camParams, rgb565, grayScale);

        // Gaussian filtering
        asm_gaussian(&camParams, grayScale, blurBuffer);

        // Sobel filtering on blurred image
        asm_sobel(&camParams, blurBuffer, sobelBuffer);

        // Output result (Sobel) to VGA
        // for (int i = 0; i < IMAGE_SIZE; i++) {
        //     grayScale[i] = sobelBuffer[i];
        // }

        // Profiling read
        asm_read_profiling(&profData, 0);
    }

    return 0;
}