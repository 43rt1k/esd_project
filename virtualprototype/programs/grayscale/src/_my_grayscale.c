#include <stdio.h>
#include <ov7670.h>
#include <swap.h>
#include <vga.h>

#define __USING_rgb565ISE__

#define IMAGE_SIZE (640*480)

#define NIOS_INSTR "l.nios_rrr"
#define CI_ID_profileCi "0x0B"
#define CI_ID_rgb565ISE "0x0C"

#define EC_0 0
#define EC_1 1
#define EC_2 2
#define EC_3 3
#define DC_0 4
#define DC_1 5
#define DC_2 6
#define DC_3 7
#define RC_0 8
#define RC_1 9
#define RC_2 10
#define RC_3 11

#define COUNTER_ENABLE_3_profileCi          ((1 << EC_3))
#define COUNTER_ENABLE_012_profileCi        ((1 << EC_0) | (1 << EC_1) | (1 << EC_2))
#define COUNTER_ENABLE_0123_profileCi       ((1 << EC_0) | (1 << EC_1) | (1 << EC_2) | (1 << EC_3))
#define COUNTER_DISABLE_012_profileCi       ((1 << DC_0) | (1 << DC_1) | (1 << DC_2))
#define COUNTER_RESET_0_profileCi           (1 << RC_0)
#define COUNTER_RESET_1_profileCi           (1 << RC_1)
#define COUNTER_RESET_2_profileCi           (1 << RC_2)
#define COUNTER_RESET_0123_profileCi        ((1 << RC_0) | (1 << RC_1) | (1 << RC_2) | (1 << RC_3))

#define COUNTER_SELECT_0_profileCi          0
#define COUNTER_SELECT_1_profileCi          1
#define COUNTER_SELECT_2_profileCi          2
#define COUNTER_SELECT_3_profileCi          3

const uint8_t SEVEN_SEG[10] = {0x3F,0x06,0x5B,0x4F,0x66,0x6D,0x7D,0x07,0x7F,0x6F};

typedef struct {
    volatile uint32_t result;
    volatile uint32_t cycles;
    volatile uint32_t stall;
    volatile uint32_t idle;
    volatile uint32_t totalCycles;
} ProfilingStatus;

void cam_init(camParameters* camParams, unsigned int* vga, ProfilingStatus* profData, volatile uint8_t* grayscale);
void cam_rgb_2_gray(camParameters* camParams, volatile uint16_t* rgb565, volatile uint8_t* grayscale);
void read_dip_n_map(volatile uint32_t* gpio);

void asm_reset_profiling();
void asm_enable_profiling_counters();
void asm_read_profiling(ProfilingStatus* profData, int printProfiling);
void asm_rgb_2_gray(uint32_t pixel1, uint32_t pixel2, uint32_t* grayPixels);

int main() {
    volatile uint32_t* vga = (uint32_t*) 0x50000020;
    volatile uint32_t* gpio = (uint32_t*) 0x40000000;

    volatile uint16_t rgb565[IMAGE_SIZE];
    volatile uint8_t grayscale[IMAGE_SIZE];

    ProfilingStatus profData;
    camParameters camParams;

    cam_init(&camParams, (unsigned int*)vga, &profData, grayscale);

    asm_reset_profiling();

    while (1) {
        takeSingleImageBlocking((uint32_t)rgb565);

        asm_enable_profiling_counters();

        read_dip_n_map(gpio);

        cam_rgb_2_gray(&camParams, rgb565, grayscale);

        asm_read_profiling(&profData, 1);
    }
}

void cam_init(camParameters* camParams, unsigned int* vga, ProfilingStatus* profData, volatile uint8_t* grayscale) {
    vga_clear();

    printf("Initialising camera (this takes up to 3 seconds)!\n");

    *camParams = initOv7670(VGA);

    printf("Done!\n");
    printf("NrOfPixels : %d\n", camParams->nrOfPixelsPerLine);

    profData->result = (camParams->nrOfPixelsPerLine <= 320) ? 
                        camParams->nrOfPixelsPerLine | 0x80000000 :
                        camParams->nrOfPixelsPerLine;
    vga[0] = swap_u32(profData->result);

    printf("NrOfLines  : %d\n", camParams->nrOfLinesPerImage);

    profData->result = (camParams->nrOfLinesPerImage <= 240) ? 
                        camParams->nrOfLinesPerImage | 0x80000000 :
                        camParams->nrOfLinesPerImage;
    vga[1] = swap_u32(profData->result);

    printf("PCLK (kHz) : %d\n", camParams->pixelClockInkHz);
    printf("FPS        : %d\n", camParams->framesPerSecond);

    vga[2] = swap_u32(2);
    vga[3] = swap_u32((uint32_t)grayscale);
}

void cam_rgb_2_gray(camParameters* camParams, volatile uint16_t* rgb565, volatile uint8_t* grayscale) {
    uint32_t* rgb = (uint32_t*)rgb565;
    uint32_t* gray = (uint32_t*)grayscale;
    uint32_t grayPixels;

    #ifdef __USING_rgb565ISE__
    for (int pixel = 0; pixel < ((camParams->nrOfLinesPerImage * camParams->nrOfPixelsPerLine) >> 1); pixel += 2) {
        uint32_t pixel1 = rgb[pixel];
        uint32_t pixel2 = rgb[pixel + 1];

        asm_rgb_2_gray(pixel1, pixel2, &grayPixels);

        gray[0] = grayPixels;
        gray++;
    }
    #else
    for (int line = 0; line < camParams->nrOfLinesPerImage; line++) {
        for (int pixel = 0; pixel < camParams->nrOfPixelsPerLine; pixel++) {
            uint16_t pixelVal = swap_u16(rgb565[line * camParams->nrOfPixelsPerLine + pixel]);
            uint32_t red1 = ((pixelVal >> 11) & 0x1F) << 3;
            uint32_t green1 = ((pixelVal >> 5) & 0x3F) << 2;
            uint32_t blue1 = (pixelVal & 0x1F) << 3;

            uint32_t grayVal = ((red1 * 54 + green1 * 183 + blue1 * 19) >> 8) & 0xFF;
            grayscale[line * camParams->nrOfPixelsPerLine + pixel] = grayVal;
        }
    }
    #endif
}

void read_dip_n_map(volatile uint32_t* gpio) {
    uint32_t raw = swap_u32(gpio[0]);
    uint8_t dips = ~raw & 0xFF;

    printf("Raw GPIO: 0x%X (dips = %d)\n", raw, dips);

    uint32_t value = (SEVEN_SEG[dips / 100] << 16) |
                     (SEVEN_SEG[(dips % 100) / 10] << 8) |
                     (SEVEN_SEG[dips % 10]);

    gpio[0] = swap_u32(value);
}

void asm_reset_profiling() {
    asm volatile (NIOS_INSTR " r0,r0,%[in2]," CI_ID_profileCi
                  :
                  : [in2] "r"(COUNTER_RESET_0123_profileCi | COUNTER_ENABLE_3_profileCi));
}

void asm_enable_profiling_counters() {
    asm volatile (NIOS_INSTR " r0,r0,%[in2]," CI_ID_profileCi
                  :
                  : [in2] "r"(COUNTER_ENABLE_012_profileCi));
}

void asm_read_profiling(ProfilingStatus* profData, int printProfiling) {
    asm volatile (NIOS_INSTR " %[out1],%[in1],%[in2]," CI_ID_profileCi
                  : [out1] "=r" (profData->cycles)
                  : [in1] "r" (COUNTER_SELECT_0_profileCi),
                    [in2] "r" (COUNTER_DISABLE_012_profileCi | COUNTER_RESET_0_profileCi));

    asm volatile (NIOS_INSTR " %[out1],%[in1],%[in2]," CI_ID_profileCi
                  : [out1] "=r" (profData->stall)
                  : [in1] "r" (COUNTER_SELECT_1_profileCi),
                    [in2] "r" (COUNTER_RESET_1_profileCi));

    asm volatile (NIOS_INSTR " %[out1],%[in1],%[in2]," CI_ID_profileCi
                  : [out1] "=r" (profData->idle)
                  : [in1] "r" (COUNTER_SELECT_2_profileCi),
                    [in2] "r" (COUNTER_RESET_2_profileCi));

    asm volatile (NIOS_INSTR " %[out1],%[in1],r0," CI_ID_profileCi
                  : [out1] "=r" (profData->totalCycles)
                  : [in1] "r" (COUNTER_SELECT_3_profileCi));

    if (printProfiling) {
        printf("Cycles: %u | Stall: %u | Idle: %u\n", profData->cycles, profData->stall, profData->idle);
    }
}

void asm_rgb_2_gray(uint32_t pixel1, uint32_t pixel2, uint32_t* grayPixels) {
    asm volatile (NIOS_INSTR " %[out1],%[in1],%[in2]," CI_ID_rgb565ISE
                  : [out1] "=r" (*grayPixels)
                  : [in1] "r" (pixel1),
                    [in2] "r" (pixel2));
}
