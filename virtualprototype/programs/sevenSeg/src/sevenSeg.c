#include <stdio.h>
#include <ov7670.h>   // Header file for the OV7670 camera interface.
#include <swap.h>     // Header file for byte-swapping functions (e.g., swap_u32, swap_u16).
#include <vga.h>      // Header file for VGA display functions.

#define __USING_rgb565ISE__
//––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––

#define IMAGE_SIZE 640*480  // Image buffer size: 640 x 480 pixels.

#define NIOS_INSTR "l.nios_rrr"         // Assembly mnemonic for issuing a custom instruction.
#define CI_ID_profileCi "0x0B"          // Custom instruction ID for profiling-related actions.
#define CI_ID_rgb565ISE "0x0C"          // Custom instruction ID for RGB565 to grayscale conversion.

// Define bit positions for controlling profiling counters:
// Each bit enables/disables/resets a different profiling counter.
// EC = Enable Counter, DC = Disable Counter, RC = Reset Counter.
#define EC_0 0  // Enable counter 0: CPU cycles
#define EC_1 1  // Enable counter 1: Stall cycles
#define EC_2 2  // Enable counter 2: Bus idle cycles
#define EC_3 3  // Enable counter 3: Total CPU cycles

#define DC_0 4  // Disable counter 0
#define DC_1 5  // Disable counter 1
#define DC_2 6  // Disable counter 2
#define DC_3 7  // Disable counter 3

#define RC_0 8   // Reset counter 0
#define RC_1 9   // Reset counter 1
#define RC_2 10  // Reset counter 2
#define RC_3 11  // Reset counter 3

#define COUNTER_SELECT_0_profileCi          0
#define COUNTER_SELECT_1_profileCi          1
#define COUNTER_SELECT_2_profileCi          2
#define COUNTER_SELECT_3_profileCi          3

// Profiling counter configurations
#define COUNTER_ENABLE_3_profileCi          (1 << EC_3)
#define COUNTER_ENABLE_012_profileCi        ((1 << EC_0) | (1 << EC_1) | (1 << EC_2))
#define COUNTER_ENABLE_0123_profileCi       ((1 << EC_0) | (1 << EC_1) | (1 << EC_2) | (1 << EC_3))
#define COUNTER_DISABLE_012_profileCi       ((1 << DC_0) | (1 << DC_1) | (1 << DC_2))
#define COUNTER_RESET_0_profileCi           (1 << RC_0)
#define COUNTER_RESET_1_profileCi           (1 << RC_1)
#define COUNTER_RESET_2_profileCi           (1 << RC_2)
#define COUNTER_RESET_0123_profileCi        ((1 << RC_0) | (1 << RC_1) | (1 << RC_2) | (1 << RC_3))

//–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
//–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––

const uint8_t SEVEN_SEG[10] = {0x3F,0x06,0x5B,0x4F,0x66,0x6D,0x7D,0x07,0x7F,0x6F};

typedef struct {
    volatile uint32_t cycles;
    volatile uint32_t stall;
    volatile uint32_t idle;
    volatile uint32_t totalCycles;
} ProfilingStatus;

void cam_init(camParameters* camParams, unsigned int* vga, volatile uint32_t* result, volatile ProfilingStatus* profData, volatile uint8_t* grayscale);
void cam_rgb_2_gray(camParameters* camParams, volatile uint16_t* rgb565, volatile uint8_t* grayscale);

void asm_reset_profiling();
void asm_enable_profiling_counters();
void asm_read_profiling(volatile ProfilingStatus* profData, uint8_t ifPrintProf);
void asm_rgb_2_gray(uint32_t pixel1, uint32_t pixel2, uint32_t* grayPixels);

//–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
//–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
// Main function: capture images from the OV7670 camera and convert them to grayscale.
// The grayscale images are displayed on a VGA monitor.
// The function also includes profiling code to measure performance metrics.
// The function runs indefinitely, capturing and processing images in a loop.

int main () {
    // Allocate a frame buffer to store the raw image in RGB565 format (16 bits per pixel)
    volatile uint16_t rgb565[IMAGE_SIZE];
    // Allocate a frame buffer for the grayscale image (8 bits per pixel)
    volatile uint8_t grayscale[IMAGE_SIZE];
    // VGA framebuffer pointer (memory-mapped I/O starting at 0x50000020)
    volatile unsigned int *vga = (unsigned int *) 0x50000020;
    // Memory-mapped GPIO (for dip switches and 7-seg)
    volatile unsigned int *gpio = (unsigned int *) 0x40000000; 

    volatile uint32_t result; // Result variable used for transferring resolution values
    camParameters camParams; // Variable to store the camera configuration
    volatile ProfilingStatus profData; // Structure to hold profiling results

    // Initialize camera and VGA display with resolution info
    cam_init(&camParams, (unsigned int*)vga, &result, &profData, grayscale);
    // Reset profiling counters and enable total cycle counter
    asm_reset_profiling();

    //=========================================================================
    while(1) {
        // Block until one image is captured into rgb565 buffer
        takeSingleImageBlocking((uint32_t) &rgb565[0]);
        
    
        
        // Read 8-bit dip switch value (active-low XOR mask)
        uint32_t dipswitch = swap_u32(gpio[0]) ^ 0xFF;


        // uint8_t dipswitch = gpio[0];
        //uint32_t dipswitch = 200;
        // Print the dip switch value
         printf("DIP Switch: %d\n", dipswitch);
        // // Convert dip value into individual digits (BCD style)
        uint32_t hundreds = dipswitch / 100;
        uint32_t tens = (dipswitch % 100) / 10;
        uint32_t ones = dipswitch % 10;
        // // Print the dip switch value and its BCD representation

        // Convert digits to 7-segment encoding and pack them into a 24-bit value
        // Format: [hundreds][tens][ones] = [byte2][byte1][byte0]
        gpio[0] = swap_u32((SEVEN_SEG[hundreds] << 16) | (SEVEN_SEG[tens] << 8) | SEVEN_SEG[ones]);

      
      
      
      
        // Enable profiling for cycle, stall, and idle counters
        asm_enable_profiling_counters();
        // Convert the RGB565 image to grayscale using either ISE or CPU fallback
        cam_rgb_2_gray(&camParams, rgb565, grayscale);
        // Read and print profiling statistics to terminal (if enabled)
        asm_read_profiling(&profData, 0);
    }
    //=========================================================================
}


//–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
// Camera initialization: configures camera, logs parameters, and prepares VGA overlay info
//–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
void cam_init(camParameters* camParams, unsigned int* vga, volatile uint32_t* result, volatile ProfilingStatus* profData, volatile uint8_t* grayscale) {
    vga_clear();  // Clear the VGA display memory (black screen)

    printf("Initialising camera (this takes up to 3 seconds)!\n");

    // Initialize the OV7670 camera with VGA resolution, and store parameters in camParams
    *camParams = initOv7670(VGA);

    printf("Done!\n");

    // Log horizontal resolution
    printf("NrOfPixels : %d\n", camParams->nrOfPixelsPerLine);

    // Encode resolution with 0x80000000 flag if it’s VGA (<= 320 px width), for use by VGA controller
    *result = (camParams->nrOfPixelsPerLine <= 320) ? 
              camParams->nrOfPixelsPerLine | 0x80000000 :
              camParams->nrOfPixelsPerLine;

    vga[0] = swap_u32(*result);  // Send to VGA controller (addressed at 0x50000020)

    // Log vertical resolution
    printf("NrOfLines  : %d\n", camParams->nrOfLinesPerImage);

    // Same flag logic for number of lines
    *result = (camParams->nrOfLinesPerImage <= 240) ? 
              camParams->nrOfLinesPerImage | 0x80000000 :
              camParams->nrOfLinesPerImage;

    vga[1] = swap_u32(*result);  // Send to VGA controller

    // Log camera performance
    printf("PCLK (kHz) : %d\n", camParams->pixelClockInkHz);
    printf("FPS        : %d\n", camParams->framesPerSecond);

    // Set grayscale mode (magic value 2) and send grayscale buffer pointer
    vga[2] = swap_u32(2);  // 2 = grayscale format
    vga[3] = swap_u32((uint32_t)grayscale);  // Base address of grayscale image buffer
}

//–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
// Converts RGB565 camera image to grayscale using ISE or software fallback
//–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
void cam_rgb_2_gray(camParameters* camParams, volatile uint16_t* rgb565, volatile uint8_t* grayscale) {
    uint32_t* rgb = (uint32_t*)rgb565;     // Recast RGB565 buffer for 32-bit access (2 pixels at a time)
    uint32_t* gray = (uint32_t*)grayscale; // Output buffer: 4 grayscale pixels per 32-bit word
    uint32_t grayPixels;                  // Temporarily stores converted grayscale pixels

    #ifdef __USING_rgb565ISE__
    // Optimized version using hardware ISE (Custom Instruction Extension)
    for (int pixel = 0; pixel < ((camParams->nrOfLinesPerImage * camParams->nrOfPixelsPerLine) >> 1); pixel += 2) {
        uint32_t pixel1 = rgb[pixel];     // Read 1st pixel pair (16-bit x 2 = 32-bit packed)
        uint32_t pixel2 = rgb[pixel + 1]; // Read 2nd pixel pair

        // Use custom instruction to compute grayscale for 4 pixels (2x2 RGB565)
        asm_rgb_2_gray(pixel1, pixel2, &grayPixels);

        gray[0] = grayPixels;  // Store result
        gray++;                // Advance 32-bit grayscale pointer
    }

    #else
    // Software fallback: manually convert each pixel to grayscale using weighted sum
    for (int line = 0; line < camParams->nrOfLinesPerImage; line++) {
        for (int pixel = 0; pixel < camParams->nrOfPixelsPerLine; pixel++) {
            // Get and byte-swap RGB565 pixel
            uint16_t pixelVal = swap_u16(rgb565[line * camParams->nrOfPixelsPerLine + pixel]);

            // Extract RGB components from RGB565 format
            uint32_t red1   = ((pixelVal >> 11) & 0x1F) << 3; // 5 bits -> 8 bits
            uint32_t green1 = ((pixelVal >> 5)  & 0x3F) << 2; // 6 bits -> 8 bits
            uint32_t blue1  = (pixelVal & 0x1F) << 3;         // 5 bits -> 8 bits

            // Apply weighted grayscale formula: 0.21 R + 0.72 G + 0.07 B
            uint32_t grayVal = ((red1 * 54 + green1 * 183 + blue1 * 19) >> 8) & 0xFF;

            // Store grayscale value
            grayscale[line * camParams->nrOfPixelsPerLine + pixel] = grayVal;
        }
    }
    #endif
}

//–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
// Profiling CI helpers — Start/reset, enable counters, and read them back into software struct
//–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––

void asm_reset_profiling() {
    // Reset all 4 counters and re-enable master counter (#3)
    asm volatile (NIOS_INSTR " r0,r0,%[in2]," CI_ID_profileCi
                  :
                  : [in2] "r"(COUNTER_RESET_0123_profileCi | COUNTER_ENABLE_3_profileCi));
}

void asm_enable_profiling_counters() {
    // Enable counters 0 (cycles), 1 (stall), 2 (bus idle)
    asm volatile (NIOS_INSTR " r0,r0,%[in2]," CI_ID_profileCi
                  :
                  : [in2] "r"(COUNTER_ENABLE_012_profileCi));
}

void asm_read_profiling(volatile ProfilingStatus* profData, uint8_t ifPrintProf) {
    // Read + reset each profiling counter one-by-one

    // Counter 0 — CPU active cycles
    asm volatile (NIOS_INSTR " %[out1],%[in1],%[in2]," CI_ID_profileCi
                  : [out1] "=r" (profData->cycles)
                  : [in1] "r" (COUNTER_SELECT_0_profileCi),
                    [in2] "r" (COUNTER_DISABLE_012_profileCi | COUNTER_RESET_0_profileCi));

    // Counter 1 — CPU stalls (e.g., waiting for memory)
    asm volatile (NIOS_INSTR " %[out1],%[in1],%[in2]," CI_ID_profileCi
                  : [out1] "=r" (profData->stall)
                  : [in1] "r" (COUNTER_SELECT_1_profileCi),
                    [in2] "r" (COUNTER_RESET_1_profileCi));

    // Counter 2 — Bus idle time (no activity on bus)
    asm volatile (NIOS_INSTR " %[out1],%[in1],%[in2]," CI_ID_profileCi
                  : [out1] "=r" (profData->idle)
                  : [in1] "r" (COUNTER_SELECT_2_profileCi),
                    [in2] "r" (COUNTER_RESET_2_profileCi));

    // Counter 3 — Total wall-clock cycle count
    asm volatile (NIOS_INSTR " %[out1],%[in1],r0," CI_ID_profileCi
                  : [out1] "=r" (profData->totalCycles)
                  : [in1] "r" (COUNTER_SELECT_3_profileCi));

    // Optionally print profiling stats to console
    if (ifPrintProf) {
        printf("Cycles: %u | Stall: %u | Idle: %u\n", profData->cycles, profData->stall, profData->idle);
    }
}

//–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
// Hardware-accelerated RGB565 to grayscale conversion via ISE
// Each 32-bit input pixel contains 2 RGB565 pixels
// The ISE outputs a 32-bit word holding 4 8-bit grayscale pixels
//–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––

void asm_rgb_2_gray(uint32_t pixel1, uint32_t pixel2, uint32_t* grayPixels) {
    asm volatile (NIOS_INSTR " %[out1],%[in1],%[in2]," CI_ID_rgb565ISE
                  : [out1] "=r" (*grayPixels)
                  : [in1] "r" (pixel1),
                    [in2] "r" (pixel2));
}

