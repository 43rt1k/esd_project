#include <ov7670.h>
#include <stdio.h>
#include <swap.h>
#include <vga.h>


#define __WITH_DMA__

// ================================================================================================
// General Define =================================================================================

// Define the instruction for the NIOS processor
#define NIOS_INSTR "l.nios_rrr"

// Define constants for custom instruction IDs
#define CI_ID_profileCi "0x0B" // Custom instruction ID for profiling
#define CI_ID_rgb565ISE "0x0C" // Custom instruction ID for RGB565 to grayscale conversion
#define CI_ID_DMA "TAKE A VALUE" //TODO: Define the correct value for DMA custom instruction ID

// Define image size and word size constants
#define IMAGE_SIZE                    (640*480) // Total number of pixels in the image
#define WORD_SIZE_BYTES               4         // Size of a word in bytes
#define WORD_TO_BYTES_SHIFT           1         // Shift value for word-to-byte conversion

// ================================================================================================
// Counter Define =================================================================================

// Define bit positions for various counters
#define EC_0_POS                      0
#define EC_1_POS                      1
#define EC_2_POS                      2
#define EC_3_POS                      3
#define DC_0_POS                      4
#define DC_1_POS                      5
#define DC_2_POS                      6
#define DC_3_POS                      7
#define RC_0_POS                      8
#define RC_1_POS                      9
#define RC_2_POS                      10
#define RC_3_POS                      11

// Define macros for enabling, disabling, and resetting counters
#define CNTR_ENABLE_3_profileCi       ( 1 << EC_3_POS)
#define CNTR_ENABLE_012_profileCi     ((1 << EC_0_POS) | (1 << EC_1_POS) | (1 << EC_2_POS))
#define CNTR_ENABLE_0123_profileCi    ((1 << EC_0_POS) | (1 << EC_1_POS) | (1 << EC_2_POS) | (1 << EC_3_POS))
#define CNTR_DISABLE_012_profileCi    ((1 << DC_0_POS) | (1 << DC_1_POS) | (1 << DC_2_POS))
#define CNTR_RESET_0_profileCi        ( 1 << RC_0_POS)
#define CNTR_RESET_1_profileCi        ( 1 << RC_1_POS)
#define CNTR_RESET_2_profileCi        ( 1 << RC_2_POS)
#define CNTR_RESET_0123_profileCi     ((1 << RC_0_POS) | (1 << RC_1_POS) | (1 << RC_2_POS) | (1 << RC_3_POS))
#define CNTR_RESET_IGNORE_profileCi   0

// Define macros for selecting counters
#define CNTR_SELECT_0_profileCi       0
#define CNTR_SELECT_1_profileCi       1
#define CNTR_SELECT_2_profileCi       2
#define CNTR_SELECT_3_profileCi       3

// ================================================================================================
// DMA Define =====================================================================================

// Define bit positions and masks for DMA operations
#define DMA_W_BIT_POS                 9
#define DMA_CONTR_BIT_POS             10
#define DMA_W_BIT                     (1 << DMA_W_BIT_POS)

// Define DMA control register addresses
#define DMA_BUS_START_ADDR            (1 << DMA_CONTR_BIT_POS)    // Address for starting DMA from bus
#define DMA_MEM_START_ADDR            (2 << DMA_CONTR_BIT_POS)    // Address for starting DMA from memory
#define DMA_BLOCK_SIZE                (3 << DMA_CONTR_BIT_POS)    // Address for setting DMA block size
#define DMA_BURST_SIZE                (4 << DMA_CONTR_BIT_POS)    // Address for setting DMA burst size
#define DMA_STATUS_CONTROL            (5 << DMA_CONTR_BIT_POS)    // Address for DMA status and control

// Define DMA configuration parameters
#define DMA_USED_CIRAM_ADDR           50
#define DMA_USED_BLOCK_SIZE           256
#define DMA_USED_BURST_SIZE           31

// Define DMA operation modes
#define DMA_START_BUS_TO_MEM          1
#define DMA_START_MEM_TO_BUS          2

// Define the total number of DMA blocks
#define DMA_TOTAL_BLOCKS              600

// ================================================================================================
// Other ==========================================================================================

// Define a structure for profiling status
typedef struct {
  volatile uint32_t result;       // Result of profiling
  volatile uint32_t cycles;       // Number of cycles
  volatile uint32_t stall;        // Number of stall cycles
  volatile uint32_t idle;         // Number of idle cycles
  volatile uint32_t totalCycles;  // Total number of cycles
} ProfilingStatus;

// ================================================================================================
// ================================================================================================
// ================================================================================================

int main () {
  uint32_t grayPixels; // Variable to store grayscale pixel data
  uint32_t pixel1, pixel2; // Variables to store RGB565 pixel data

  volatile uint16_t rgb565[IMAGE_SIZE]; // Array to store RGB565 image data
  volatile uint8_t grayscale[IMAGE_SIZE]; // Array to store grayscale image data

  volatile unsigned int *vga = (unsigned int *) 0X50000020; // VGA memory-mapped address
  volatile unsigned int *gpio = (unsigned int *) 0x40000000; // GPIO memory-mapped address
  
  ProfilingStatus profData; // Profiling data structure
  camParameters camParams; // Camera parameters structure

  vga_clear(); // Clear the VGA display

  #ifdef __WITH_DMA__  
  /* set up the generic dma parameters */
  asm_DMA_W(DMA_BLOCK_SIZE, DMA_USED_BLOCK_SIZE); // Set DMA block size
  asm_DMA_W(DMA_BURST_SIZE, DMA_USED_BURST_SIZE); // Set DMA burst size
  #endif
  
  cam_init(&camParams, (unsigned int*)vga, &profData, grayscale); // Initialize the camera
  asm_PROF_reset(); // Reset profiling counters

  while(1) {
    takeSingleImageBlocking((uint32_t) &rgb565[0]); // Capture a single image

    asm_PROF_enable_counters(); // Enable profiling counters

    uint32_t* rgb = (uint32_t *) &rgb565[0]; // Pointer to RGB565 image data
    uint32_t* gray = (uint32_t *) &grayscale[0]; // Pointer to grayscale image data
    
    #ifdef __WITH_DMA__

    uint32_t dmaBuffer = 0; // DMA buffer index
    uint32_t workBuffer = DMA_USED_BLOCK_SIZE; // Working buffer index
    uint32_t status; // DMA status
    uint32_t p_rgb = (uint32_t) &rgb[0]; // Pointer to RGB565 data
    uint32_t p_gray = (uint32_t) &gray[0]; // Pointer to grayscale data

    /* perform the first initial DMA */
    asm_DMA_W(DMA_BUS_START_ADDR, p_rgb); // Set DMA bus start address
    p_rgb += DMA_USED_BLOCK_SIZE * WORD_SIZE_BYTES; // Increment pointer
    asm_DMA_W(DMA_MEM_START_ADDR, dmaBuffer); // Set DMA memory start address
    asm_DMA_W(DMA_STATUS_CONTROL, DMA_START_BUS_TO_MEM); // Start DMA bus-to-memory transfer

    asm_DMA_wait_end(); // Wait for DMA transfer to complete

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

        asm_RGB565_2_gray(pixel1, pixel2, &grayPixels); // Convert RGB565 to grayscale
        grayPixels = swap_u32(grayPixels); // Swap byte order of grayscale pixels
      }

      asm_DMA_W((workBuffer+(pixel>>1)), grayPixels); // Write grayscale pixels to DMA buffer

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

    #else

    no_DMA_grayscale(&camParams, &grayPixels, rgb, gray); // Perform grayscale conversion without DMA

    #endif

  asm_PROF_read_all(&profData, true); // Read and print profiling data

  }
}

// ================================================================================================
// Other Functions ================================================================================

void cam_init(camParameters* camParams, unsigned int* vga, ProfilingStatus* profData, volatile uint8_t* grayscale) {
  vga_clear(); // Clear the VGA display

  printf("Initialising camera (this takes up to 3 seconds)!\n");

  *camParams = initOv7670(VGA); // Initialize the OV7670 camera

  printf("Done!\n");
  printf("NrOfPixels : %d\n", camParams->nrOfPixelsPerLine); // Print number of pixels per line

  profData->result = (camParams->nrOfPixelsPerLine <= 320) ? 
                      camParams->nrOfPixelsPerLine | 0x80000000 :
                      camParams->nrOfPixelsPerLine;
  vga[0] = swap_u32(profData->result); // Store result in VGA memory

  printf("NrOfLines  : %d\n", camParams->nrOfLinesPerImage); // Print number of lines per image

  profData->result = (camParams->nrOfLinesPerImage <= 240) ? 
                      camParams->nrOfLinesPerImage | 0x80000000 :
                      camParams->nrOfLinesPerImage;
  vga[1] = swap_u32(profData->result); // Store result in VGA memory

  printf("PCLK (kHz) : %d\n", camParams->pixelClockInkHz); // Print pixel clock frequency
  printf("FPS        : %d\n", camParams->framesPerSecond); // Print frames per second

  vga[2] = swap_u32(2); // Store constant value in VGA memory
  vga[3] = swap_u32((uint32_t)grayscale); // Store grayscale buffer address in VGA memory
}

// ================================================================================================
// Grayscale Asm Functions ========================================================================

// Function to convert two RGB565 pixels to grayscale using a custom instruction
void asm_RGB565_2_gray(uint32_t pixel1, uint32_t pixel2, uint32_t* grayPixels) {
  asm volatile (NIOS_INSTR " %[out1],%[in1],%[in2]," CI_ID_rgb565ISE
                : [out1] "=r" (*grayPixels) // Output: grayscale pixels
                : [in1] "r" (pixel1),       // Input: first RGB565 pixel
                  [in2] "r" (pixel2));      // Input: second RGB565 pixel
}

// ================================================================================================
// Profiling Asm Functions ========================================================================

// Function to perform a profiling operation using a custom instruction
void asm_PROF_R(uint32_t *_out1, uint32_t _in1, uint32_t _in2) {
  asm volatile (NIOS_INSTR " %[out1],%[in1],%[in2]," CI_ID_profileCi
                : [out1] "=r" (*_out1) // Output: profiling result
                : [in1] "r" (_in1),    // Input: first operand
                  [in2] "r" (_in2));   // Input: second operand
}

// Function to enable profiling counters
void asm_PROF_enable_counters() {
  asm volatile (NIOS_INSTR " r0,r0,%[in2]," CI_ID_profileCi
                :
                : [in2] "r"(CNTR_ENABLE_012_profileCi)); // Enable specific counters
}

// Function to reset profiling counters
void asm_PROF_reset() {
  asm volatile (NIOS_INSTR " r0,r0,%[in2]," CI_ID_profileCi
                :
                : [in2] "r"(CNTR_RESET_0123_profileCi | CNTR_ENABLE_3_profileCi)); // Reset and enable counters
}

// Function to read all profiling data and optionally print it
void asm_PROF_read_all(ProfilingStatus* profData, int printProfiling) {
  // Read cycles counter
  asm_PROF_R(&profData->cycles, 
             CNTR_SELECT_0_profileCi, 
             CNTR_DISABLE_012_profileCi | CNTR_RESET_0_profileCi);
  
  // Read stall counter
  asm_PROF_R(&profData->stall, 
             CNTR_SELECT_1_profileCi, 
             CNTR_RESET_1_profileCi);

  // Read idle counter
  asm_PROF_R(&profData->idle, 
             CNTR_SELECT_2_profileCi, 
             CNTR_RESET_2_profileCi);

  // Read total cycles counter
  asm_PROF_R(&profData->totalCycles, 
             CNTR_SELECT_3_profileCi, 
             CNTR_RESET_IGNORE_profileCi);
            
  // Print profiling data if requested
  if (printProfiling) {
      printf("Cycles: %u | Stall: %u | Idle: %u\n", profData->cycles, profData->stall, profData->idle);
  }
}

// ================================================================================================
// DMA Asm Functions ==============================================================================

// Function to write data to a DMA register using a custom instruction
void asm_DMA_W(uint32_t _in1, uint32_t _in2) {
  asm volatile(NIOS_INSTR " r0,%[in1],%[in2]," CI_ID_DMA 
                :
                : [in1] "r"(_in1 | DMA_W_BIT), // Input: register address with write bit
                  [in2] "r"(_in2));           // Input: data to write
}

// Function to read data from a DMA register using a custom instruction
void asm_DMA_R(uint32_t *_out1, uint32_t _in1) {
  asm volatile(NIOS_INSTR " %[out1],%[in1],r0," CI_ID_DMA 
                : [out1] "=r" (*_out1) // Output: data read from register
                : [in1] "r" (_in1));   // Input: register address
}

// Function to perform grayscale conversion without using DMA
void no_DMA_grayscale(camParameters* camParams, uint32_t* grayPixels, uint32_t* rgb, uint32_t* gray) {
  for (int pixel = 0; pixel < ((camParams->nrOfLinesPerImage * camParams->nrOfPixelsPerLine) >> 1); pixel += 2) {
    uint32_t pixel1 = rgb[pixel];     // Read first RGB565 pixel
    uint32_t pixel2 = rgb[pixel + 1]; // Read second RGB565 pixel
    
    asm_RGB565_2_gray(pixel1, pixel2, grayPixels); // Convert to grayscale
    
    *gray = *grayPixels; // Store grayscale pixel
    gray++;
  }
}

// Function to wait for the DMA operation to complete
void asm_DMA_wait_end(uint32_t* status) {
  do { 
    asm_DMA_R(status, DMA_STATUS_CONTROL); // Read DMA status
  } while (*status != 0); // Wait until DMA is idle
}
