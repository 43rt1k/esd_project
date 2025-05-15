#include <stdio.h>
#include <ov7670.h>   // Header file for the OV7670 camera interface.
#include <swap.h>     // Header file for byte-swapping functions (e.g., swap_u32, swap_u16).
#include <vga.h>      // Header file for VGA display functions.

#define __USING_rgb565ISE__
//–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––

#define IMAGE_SIZE 640*480

#define NIOS_INSTR "l.nios_rrr"
#define CI_ID_profileCi "0x0B"
#define CI_ID_rgb565ISE "0x0C"

// Define bit positions for controlling counters via valueB:
// Enable counters (EC_i) – bits 0..3
#define EC_0 0  // Counts the number of CPU-cycles when enabled.
#define EC_1 1  // Counts the µC stall cycles when enabled.
#define EC_2 2  // Counts the bus-idle cycles when enabled.
#define EC_3 3  // Counts the number of CPU-cycles when enabled.

// Disable counters (DC_i) – bits 4..7
#define DC_0 4
#define DC_1 5
#define DC_2 6
#define DC_3 7

// Reset counters (RC_i) – bits 8..11
#define RC_0 8
#define RC_1 9
#define RC_2 10
#define RC_3 11

// Counter 0 and 3: Counts the number of CPU-cycles when enabled.
// Counter 1: Counts the µC stall cycles when enabled.
// Counter 2: Counts the bus-idle cycles when enabled.
#define COUNTER_ENABLE_3_profileCi          (1 << EC_3)
#define COUNTER_ENABLE_012_profileCi        (1 << EC_0) | (1 << EC_1) | (1 << EC_2)
#define COUNTER_ENABLE_0123_profileCi       (1 << EC_0) | (1 << EC_1) | (1 << EC_2) | (1 << EC_3)

#define COUNTER_DISABLE_012_profileCi       (1 << DC_0) | (1 << DC_1) | (1 << DC_2)

#define COUNTER_RESET_0_profileCi           (1 << RC_0)
#define COUNTER_RESET_1_profileCi           (1 << RC_1)
#define COUNTER_RESET_2_profileCi           (1 << RC_2)
#define COUNTER_RESET_0123_profileCi        (1 << RC_0) | (1 << RC_1) | (1 << RC_2) | (1 << RC_3)

#define COUNTER_SELECT_0_profileCi          0
#define COUNTER_SELECT_1_profileCi          1
#define COUNTER_SELECT_2_profileCi          2
#define COUNTER_SELECT_3_profileCi          3
//–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
//–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
// Main function: capture images from the OV7670 camera and convert them to grayscale.
// The grayscale images are displayed on a VGA monitor.
// The function also includes profiling code to measure performance metrics.
// The function runs indefinitely, capturing and processing images in a loop.


int main () {
  // Declare a frame buffer to store the raw camera image in RGB565 format.
  // There are 640x480 pixels; each pixel is 16 bits.
  volatile uint16_t rgb565[IMAGE_SIZE];

  // Declare a frame buffer for the grayscale image.
  // Each pixel is 8 bits.
  volatile uint8_t grayscale[IMAGE_SIZE];
  // Variables to hold profiling/timing information.
  volatile uint32_t result, 
                    cycles, 
                    stall, 
                    idle,
                    totalCycles;

  // Pointer to a memory-mapped VGA controller located at address 0x50000020.
  volatile unsigned int *vga = (unsigned int *) 0X50000020;

  //–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
  // Initialize the camera and VGA display.
  //–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
  // Structure to hold camera parameters (resolution, pixel clock, etc.).
  camParameters camParams;

  // Clear the VGA display.
  vga_clear();

  // Print a message indicating that camera initialization is starting.
  printf("Initialising camera (this takes up to 3 seconds)!\n" );
  
  // Initialize the OV7670 camera in VGA mode. The returned structure contains camera settings.
  camParams = initOv7670(VGA);

  // Indicate that camera initialization is done.
  printf("Done!\n" );
  
  // Print the number of pixels per line reported by the camera.
  printf("NrOfPixels : %d\n", camParams.nrOfPixelsPerLine );
  
  // Compute a value based on the number of pixels per line.
  // If the number of pixels is less than or equal to 320, OR it with 0x80000000 
  result = (camParams.nrOfPixelsPerLine <= 320) ? 
            camParams.nrOfPixelsPerLine | 0x80000000 : 
            camParams.nrOfPixelsPerLine;
             
  // Write the result (after swapping byte order) to vga[0]
  vga[0] = swap_u32(result);

  // Print the number of lines per image reported by the camera.
  printf("NrOfLines  : %d\n", camParams.nrOfLinesPerImage );
  
  // Compute a similar value for the number of lines (vertical resolution).
  result = (camParams.nrOfLinesPerImage <= 240) ? 
            camParams.nrOfLinesPerImage | 0x80000000 : 
            camParams.nrOfLinesPerImage;
            
  // Write the vertical resolution configuration (after byte-swapping) to vga[1].
  vga[1] = swap_u32(result);

  // Print additional camera parameters.
  printf("PCLK (kHz) : %d\n", camParams.pixelClockInkHz );
  printf("FPS        : %d\n", camParams.framesPerSecond );

  // Create a pointer to the rgb565 buffer 
  uint32_t * rgb = (uint32_t *) &rgb565[0];

  // A variable to store the number of grayscale pixels 
  uint32_t grayPixels;

  // Configure the VGA controller:
  // vga[2] is set to a constant value (2) indicating a particular display mode (e.g., grayscale mode).
  vga[2] = swap_u32(2);
  
  // vga[3] is set to the address of the grayscale buffer, after swapping the byte order.
  vga[3] = swap_u32((uint32_t) &grayscale[0]);

  //–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––

  // Reset the profiling counters and enable the overall counter(3).
  asm volatile (NIOS_INSTR " r0,r0,%[in2]," CI_ID_profileCi
    ::[in2]"r"(COUNTER_RESET_0123_profileCi | COUNTER_ENABLE_3_profileCi));
 
  //–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
  // Main loop: continuously capture and process images.
  //–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––

  
  while(1) {
    
    // Capture an image from the camera.
    // takeSingleImageBlocking waits until the image is fully captured and stores it in rgb565.
    takeSingleImageBlocking((uint32_t) &rgb565[0]);
 
    //–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
    //–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
    // Enable counters 0, 1, 2 for profiling.
    asm volatile (NIOS_INSTR " r0,r0,%[in2]," CI_ID_profileCi 
                  : // No output operands
                  : [in2] "r"(COUNTER_ENABLE_012_profileCi));
    //–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
    //–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
    uint32_t * rgb = (uint32_t *) &rgb565[0];
    
    #ifdef __USING_rgb565ISE__
    // Create a pointer to the grayscale buffer.
    uint32_t * gray = (uint32_t *) &grayscale[0];
    

    for (int pixel = 0; pixel < ((camParams.nrOfLinesPerImage*camParams.nrOfPixelsPerLine) >> 1); pixel +=2) {
      uint32_t pixel1 = rgb[pixel];
      uint32_t pixel2 = rgb[pixel+1];
      asm volatile (NIOS_INSTR " %[out1],%[in1],%[in2]," CI_ID_rgb565ISE
                  : [out1] "=r" (grayPixels)
                  : [in1] "r" (pixel1),
                    [in2] "r" (pixel2));

      gray[0] = grayPixels;
      gray++;
    }
    #else
    for (int line = 0; line < camParams.nrOfLinesPerImage; line++) {
      for (int pixel = 0; pixel < camParams.nrOfPixelsPerLine; pixel++) {

        uint16_t rgb = swap_u16(rgb565[line*camParams.nrOfPixelsPerLine+pixel]);
        uint32_t red1 = ((rgb >> 11) & 0x1F) << 3;
        uint32_t green1 = ((rgb >> 5) & 0x3F) << 2;
        uint32_t blue1 = (rgb & 0x1F) << 3;

        uint32_t gray = ((red1*54+green1*183+blue1*19) >> 8)&0xFF;
        grayscale[line*camParams.nrOfPixelsPerLine+pixel] = gray;
      }
    }
    
    
    
    #endif


    // The following inline assembly instructions use the custom "l.nios_rrr" instruction to 
    // read profiling/timing information from the system.
    // Each instruction sets a parameter (e.g., cycles, stall, idle) by passing certain immediate values.
    //–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
    //–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
    // Read the total number of cycles for this frame.
    asm volatile (NIOS_INSTR " %[out1],%[in1],%[in2]," CI_ID_profileCi
                  : [out1] "=r" (cycles)
                  : [in1] "r" (COUNTER_SELECT_0_profileCi),
                    [in2] "r" (COUNTER_DISABLE_012_profileCi | COUNTER_RESET_0_profileCi));
    //–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
    // Read a stall-related metric into 'stall' using an immediate value that encodes the desired parameter.
    asm volatile (NIOS_INSTR " %[out1],%[in1],%[in2]," CI_ID_profileCi
                  : [out1] "=r" (stall)
                  : [in1] "r" (COUNTER_SELECT_1_profileCi),
                    [in2] "r" (COUNTER_RESET_1_profileCi));
    //–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
    // Read an idle-related metric into 'idle' similarly.
    asm volatile (NIOS_INSTR " %[out1],%[in1],%[in2]," CI_ID_profileCi
                  : [out1] "=r" (idle)
                  : [in1] "r" (COUNTER_SELECT_2_profileCi),
                    [in2] "r" (COUNTER_RESET_2_profileCi));
    //–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––

    asm volatile (NIOS_INSTR " %[out1],%[in1],r0," CI_ID_profileCi
                  : [out1] "=r" (totalCycles)
                  : [in1] "r" (COUNTER_SELECT_3_profileCi));

    //–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
    //–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––         

    printf("Cycles: %2d | Stall: %2d | Idle: %2d\n", cycles, stall, idle);
  }

}
