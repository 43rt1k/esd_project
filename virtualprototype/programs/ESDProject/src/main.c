#include <stdio.h>
#include "profiling.h"
#include "camera.h"
#include "gpio.h"

int main() {
    // Frame buffers
    volatile uint16_t rgb565[IMAGE_SIZE];
    volatile uint8_t grayScale[IMAGE_SIZE];
    volatile uint8_t sobelBuffer[IMAGE_SIZE];

    // Peripherals
    volatile unsigned int* vga = (unsigned int*)0x50000020;
    volatile unsigned int* gpio = (unsigned int*)0x40000000;

    volatile uint32_t result;
    camParameters camParams;
    volatile ProfilingStatus profData;

    // Initialization
    cam_init(&camParams, (unsigned int*)vga, &result, grayScale);
    asm_reset_profiling();

    while (1) {
        // Image capture
        takeSingleImageBlocking((uint32_t)&rgb565[0]);

        // DIP switch value to 7-segment
        uint32_t dipSwitch = gpio_get_DipSw(gpio);
        gpio_set_sevenSeg(gpio, dipSwitch);

        // Profiling start
        asm_enable_profiling_counters();

        // RGB565 -> grayscale
        cam_rgb_2_gray(&camParams, rgb565, grayScale);

        // Sobel filtering
        asm_sobel(&camParams, grayScale, sobelBuffer);

        // Output result (Sobel) to VGA
        for (int i = 0; i < IMAGE_SIZE; i++) {
            grayScale[i] = sobelBuffer[i];
        }

        // Profiling read
        asm_read_profiling(&profData, 1);
    }

    return 0;
}