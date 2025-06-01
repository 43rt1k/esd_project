#include <stdio.h>
#include "profiling.h"
#include "camera.h"
#include "gpio.h"
#include "memory.h"
#include "swap.h"
#include <stdint.h>

#define CI_ID_LED_MATRIX "0x15"

void asm_ledMatrix_W(uint32_t _in1, uint32_t _in2) {
    asm volatile(NIOS_INSTR " r0,%[in1],%[in2]," CI_ID_LED_MATRIX
                 :
                 : [in1] "r"(_in1),
                   [in2] "r"(_in2));
}
uint8_t matrix1[12][10] = {
    {1,1,1,1,1,1,1,1,1,1},  // row 0: all ON
    {1,1,0,0,0,0,0,0,0,1},  // row 1
    {1,0,1,0,0,0,0,0,0,1},  // row 2
    {1,0,0,1,0,0,0,0,0,1},  // row 3
    {1,0,0,0,0,0,0,0,0,1},  // row 4
    {1,0,0,0,0,0,0,0,0,1},  // row 5
    {1,0,0,0,0,0,0,0,0,1},  // row 6
    {1,0,0,0,0,0,0,0,0,1},  // row 7
    {1,0,0,0,0,0,0,0,0,1},  // row 8
    {1,0,0,0,0,0,0,0,0,1},  // row 9
    {1,0,0,0,0,0,0,0,0,1},  // row 10
    {1,1,1,1,1,1,1,1,1,1}   // row 11: all ON
};

/*
 * (2) “matrix2” has been transposed from your original 10×12,
 *     so it now occupies 12 rows × 10 columns.
 *     That way, the diagonal‐and‐middle‐bars pattern remains recognizable.
 */
uint8_t matrix2[12][10] = {
    {1,0,0,0,0,0,0,0,0,1},  // new row 0  (was old col 0)
    {0,1,0,0,0,0,0,0,1,0},  // new row 1  (was old col 1)
    {0,0,1,0,0,0,0,1,0,0},  // new row 2  (was old col 2)
    {0,0,0,1,0,0,1,0,0,0},  // new row 3  (was old col 3)
    {0,0,0,0,1,1,0,0,0,0},  // new row 4  (was old col 4)
    {0,0,0,0,1,1,0,0,0,0},  // new row 5  (was old col 5)
    {0,0,0,0,1,1,0,0,0,0},  // new row 6  (was old col 6)
    {0,0,0,0,1,1,0,0,0,0},  // new row 7  (was old col 7)
    {0,0,0,1,0,0,1,0,0,0},  // new row 8  (was old col 8)
    {0,0,1,0,0,0,0,1,0,0},  // new row 9  (was old col 9)
    {0,1,0,0,0,0,0,0,1,0},  // new row 10 (was old col 10)
    {1,0,0,0,0,0,0,0,0,1}   // new row 11 (was old col 11)
};

/*
 * (3) “matrix3” has also been transposed from your original 10×12,
 *     so you get a 12×10 representation of the “vertical‐bars + full middle rows” pattern.
 */
uint8_t matrix3[12][10] = {
    {1,1,1,1,1,1,1,1,1,1},  // new row 5  (old col 5)
    {0,0,0,0,1,1,0,0,0,0},  // new row 1  (old col 1)
    {0,0,0,0,1,1,0,0,0,1},  // new row 0  (old col 0)
    {0,0,0,0,1,1,0,0,0,0},  // new row 2  (old col 2)
    {0,0,0,0,1,1,0,0,0,0},  // new row 3  (old col 3)
    {0,0,0,0,1,1,0,0,0,0},  // new row 4  (old col 4)
    {0,0,0,0,1,1,0,0,0,0},  // new row 7  (old col 7)
    {1,1,1,1,1,1,1,1,1,1},  // new row 6  (old col 6)
    {0,0,0,0,1,1,0,0,0,0},  // new row 8  (old col 8)
    {0,0,0,0,1,1,0,0,0,0},  // new row 9  (old col 9)
    {0,0,0,0,1,1,0,0,0,0},  // new row 10 (old col 10)
    {0,0,0,0,1,1,0,0,0,0}   // new row 11 (old col 11)
};

/*
 * Updated encode_matrix: now iterates over 12 rows and 10 columns,
 * and computes flat_index = row*10 + col (0..119). The split into
 * A1/B1/A2/B2 is unchanged (each holds 30 bits, for 120 total).
 */
void encode_matrix( const uint8_t matrix[12][10],
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

    volatile uint16_t rgb565[IMAGE_SIZE];
    volatile uint8_t grayScale[IMAGE_SIZE];
    volatile uint8_t blurBuffer[IMAGE_SIZE];   // Gaussian output
    volatile uint8_t sobelBuffer[IMAGE_SIZE];  // Sobel output

    // Peripherals
    volatile unsigned int* vga = (unsigned int*)0x50000020;
    volatile unsigned int* gpio = (unsigned int*)0x40000000;

    camParameters camParams;
    volatile ProfilingStatus profData;

    // Initialization
    uint32_t* vgaOutputBuff = (uint32_t*)sobelBuffer;
    vga_init(&camParams, (unsigned int*)vga, vgaOutputBuff);
    
    
    asm_reset_profiling();

    uint32_t A1, B1, A2, B2;
    encode_matrix(matrix3, &A1, &B1, &A2, &B2);

    while (1) {
        // Image capture
        takeSingleImageBlocking((uint32_t)&rgb565[0]);

        // DIP switch value to 7-segment
        uint32_t dipSwitch = gpio_get_DipSw(gpio);
        gpio_set_sevenSeg(gpio, dipSwitch);

        // Profiling start
        asm_enable_profiling_counters();
        
        // Display first part
        asm_ledMatrix_W(A1, B1);
        asm_ledMatrix_W(A2, B2);

        for (int i = 0; i < 12; i++) {
            for (int j = 0; j < 10; j++) {
                printf("%d ", matrix3[i][j]);
            }
            printf("\n");
        }
        printf("A1 = 0x%08X, B1 = 0x%08X, A2 = 0x%08X, B2 = 0x%08X\n", A1, B1, A2, B2);

        // Display second part
       // asm_ledMatrix_W(valueA2, valueB2);









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
