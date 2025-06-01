#include <stdio.h>
#include "profiling.h"
#include "camera.h"
#include "gpio.h"
#include "memory.h"
#include "game.h"
#include "swap.h"
#include <stdint.h>

#define CI_ID_LED_MATRIX "0x15"


 
static Direction mapJoystickToDirection(uint32_t nJoystick)
{
    switch (nJoystick) {
        case 0x1E000000u:
            // “top” pressed → go UP
            return UP;

        case 0x1B000000u:
            // “bottom” pressed → go DOWN
            return DOWN;

        case 0x1D000000u:
            // this code was labeled “down,” but it actually corresponds to LEFT
            return LEFT;

        case 0x17000000u:
            // “right” pressed → go RIGHT
            return RIGHT;

        default:
            // any other value: do nothing (keep previous direction)
            break;
    }
}


void asm_ledMatrix_W(uint32_t _in1, uint32_t _in2) {
    asm volatile(NIOS_INSTR " r0,%[in1],%[in2]," CI_ID_LED_MATRIX
                 :
                 : [in1] "r"(_in1),
                   [in2] "r"(_in2));
}

void encode_matrix(int8_t matrix[12][10],
                    uint32_t *valueA1, uint32_t *valueB1,
                    uint32_t *valueA2, uint32_t *valueB2) {

    uint32_t A1 = 0, B1 = 0, A2 = 0, B2 = 0;
    int flat_index;

    for (int row = 0; row < 12; ++row) {
        for (int col = 0; col < 10; ++col) {
            if (matrix[row][9-col]) {
                flat_index = row * 10 + col;  // ranges 0..119

                if      (flat_index < 30) A1 |= (1u << flat_index);
                else if (flat_index < 60) B1 |= (1u << (flat_index - 30));
                else if (flat_index < 90) A2 |= (1u << (flat_index - 60));
                else                      B2 |= (1u << (flat_index - 90));
            
            }
        }
    }

    // Force bit-30 of A1 to 1; bit-31 remains 0
    A1 |= (1u << 30);

    *valueA1 = A1;
    *valueB1 = B1;
    *valueA2 = A2;
    *valueB2 = B2;
}


int main() {
    // Frame buffers
    static int8_t field[FIELD_WIDTH][FIELD_HEIGHT];

    volatile uint16_t rgb565[IMAGE_SIZE];
    volatile uint8_t grayScale[IMAGE_SIZE];
    volatile uint8_t blurBuffer[IMAGE_SIZE];   // Gaussian output
    volatile uint8_t sobelBuffer[IMAGE_SIZE];  // Sobel output

    // Peripherals
    volatile unsigned int* vga = (unsigned int*)0x50000020;
    volatile unsigned int* gpio_dip7 = (unsigned int*)0x40000000;
    volatile unsigned int* gpio_butt = (unsigned int*)0x40000100;

    camParameters camParams;
    volatile ProfilingStatus profData;

    // Initialization
    uint32_t* vgaOutputBuff = (uint32_t*)sobelBuffer;
    vga_init(&camParams, (unsigned int*)vga, vgaOutputBuff);
    
    
    asm_reset_profiling();



    uint32_t A1, B1, A2, B2;
    // encode_matrix(matrix3, &A1, &B1, &A2, &B2);



    while (1) {
        uint32_t nJoystick = gpio_butt[0];
        

        updateSnakeGame(field, mapJoystickToDirection(nJoystick));  // Example command, can be replaced with actual input handling
        encode_matrix(field, &A1, &B1, &A2, &B2);
        // Image capture
        takeSingleImageBlocking((uint32_t)&rgb565[0]);

        // DIP switch value to 7-segment
        uint32_t dipSwitch = gpio_get_DipSw(gpio_dip7);
        gpio_set_sevenSeg(gpio_dip7, dipSwitch);

        // Profiling start
        asm_enable_profiling_counters();
        
        // Display first part
        asm_ledMatrix_W(A1, B1);
        asm_ledMatrix_W(A2, B2);
        // printf("Joystick value: 0x%08X\n", nJoystick);
        
    

        // for (int i = 0; i < IMAGE_SIZE; i = i + 1) {
        //     printf("rgb565[%d] = 0x%04X\n", i, rgb565[i]);
        // }
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












        // uint32_t dmaBuffer = 0; // DMA buffer index
        // uint32_t workBuffer = DMA_USED_BLOCK_SIZE; // Working buffer index
        // uint32_t status; // DMA status
        // uint32_t p_rgb = (uint32_t)(uintptr_t)&rgb565[0];
        // uint32_t p_gray = (uint32_t)(uintptr_t) &grayScale[0];


        // // perform the first initial DMA 
        // asm_DMA_W(DMA_BUS_START_ADDR, p_rgb); // Set DMA bus start address

        // p_rgb += DMA_USED_BLOCK_SIZE * WORD_SIZE_BYTES; // Increment pointer
        // asm_DMA_W(DMA_MEM_START_ADDR, dmaBuffer); // Set DMA memory start address
        // asm_DMA_W(DMA_STATUS_R, DMA_START_BUS_TO_MEM); // Start DMA bus-to-memory transfer

        // asm_DMA_wait_end(); // Wait for DMA transfer to complete
        // printf("DMA transfer completed.\n");

        //   for (int i = 0 ; i < DMA_TOTAL_BLOCKS; i++) {
        //     // swap buffers 
        //     status = dmaBuffer; // Swap DMA buffers
        //     dmaBuffer = workBuffer;
        //     workBuffer = status;
        //     printf("Swapped buffers: dmaBuffer = %u, workBuffer = %u\n", dmaBuffer, workBuffer);
        //     printf("Processing DMA block %d\n", i);
        //     // perform DMA in 
        //     if (i < (DMA_TOTAL_BLOCKS - 1)) {
        //         asm_DMA_W(DMA_BUS_START_ADDR, p_rgb); // Set DMA bus start address

        //         p_rgb += DMA_USED_BLOCK_SIZE * WORD_SIZE_BYTES; // Increment pointer

        //         asm_DMA_W(DMA_MEM_START_ADDR, dmaBuffer); // Set DMA memory start address
                
        //         asm_DMA_W(DMA_STATUS_R, DMA_START_BUS_TO_MEM); // Start DMA bus-to-memory transfer
        //     }

        //     // perform transformation 
        //     for (uint16_t pixel = 0 ; pixel < DMA_USED_BLOCK_SIZE ; pixel += 2) {

        //         asm_DMA_R(&pixel1, workBuffer + pixel); // Read pixel1 from DMA buffer
        //         asm_DMA_R(&pixel2, workBuffer + pixel + 1); // Read pixel2 from DMA buffer

        //         pixel1 = swap_u32(pixel1); // Swap byte order of pixel1
        //         pixel2 = swap_u32(pixel2); // Swap byte order of pixel2

        //         grayPixels = asm_rgb_2_gray(pixel1, pixel2); // Convert RGB565 to grayscale
        //         grayPixels = swap_u32(grayPixels); // Swap byte order of grayscale pixels
        //         asm_DMA_W((workBuffer+(pixel>>1)), grayPixels); // Write grayscale pixels to DMA buffer
        //     }


        //     asm_DMA_wait_end(); // Wait for DMA transfer to complete

        //     // perform DMA out 
        //     asm_DMA_W(DMA_BUS_START_ADDR, p_gray); // Set DMA bus start address

        //     p_gray += (DMA_USED_BLOCK_SIZE << WORD_TO_BYTES_SHIFT); // Increment pointer

        //     asm_DMA_W(DMA_BLOCK_SIZE, (DMA_USED_BLOCK_SIZE >> WORD_TO_BYTES_SHIFT)); // Set DMA block size
        //     asm_DMA_W(DMA_MEM_START_ADDR, workBuffer); // Set DMA memory start address
        //     asm_DMA_W(DMA_STATUS_R, DMA_START_MEM_TO_BUS); // Start DMA memory-to-bus transfer

        //     asm_DMA_wait_end(); // Wait for DMA transfer to complete
            
        //     asm_DMA_W(DMA_BLOCK_SIZE, DMA_USED_BLOCK_SIZE); // Reset DMA block size
        // }



