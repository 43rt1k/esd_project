#include <stdio.h>
#include <ov7670.h>
#include <swap.h>
#include <vga.h>

#define __WITH_CI

int main () {
  const uint8_t sevenSeg[10] = {0x3F,0x06,0x5B,0x4F,0x66,0x6D,0x7D,0x07,0x7F,0x6F};
  volatile uint16_t rgb565[640*480];
  volatile uint8_t grayscale[640*480];
  volatile uint32_t result, cycles, stall, idle;
  volatile unsigned int *vga = (unsigned int *) 0x50000020;
  volatile unsigned int *gpio = (unsigned int *) 0x40000000;
  camParameters camParams;
  vga_clear();

  printf("Initialising camera (this takes up to 3 seconds)!\n");
  camParams = initOv7670(VGA);
  printf("Done!\n");
  printf("NrOfPixels : %d\n", camParams.nrOfPixelsPerLine);
  result = (camParams.nrOfPixelsPerLine <= 320) ? camParams.nrOfPixelsPerLine | 0x80000000 : camParams.nrOfPixelsPerLine;
  vga[0] = swap_u32(result);
  printf("NrOfLines  : %d\n", camParams.nrOfLinesPerImage);
  result = (camParams.nrOfLinesPerImage <= 240) ? camParams.nrOfLinesPerImage | 0x80000000 : camParams.nrOfLinesPerImage;
  vga[1] = swap_u32(result);
  printf("PCLK (kHz) : %d\n", camParams.pixelClockInkHz);
  printf("FPS        : %d\n", camParams.framesPerSecond);

  vga[2] = swap_u32(2); // Display mode
  vga[3] = swap_u32((uint32_t) &grayscale[0]); // Grayscale buffer pointer

  while (1) {
    takeSingleImageBlocking((uint32_t) &rgb565[0]);

    // Trigger grayscale ISE (opcode 0x0C)
    uint32_t grayPixels;
    uint32_t *rgb = (uint32_t *) &rgb565[0];
    uint8_t *gray = (uint8_t *) &grayscale[0];

    asm volatile ("l.nios_rrr r0, r0, %[in2], 0xC" :: [in2] "r" (7));

    uint32_t dipswitch = swap_u32(gpio[0]) ^ 0xFF;
    uint32_t hundreds = dipswitch / 100;
    uint32_t tens = (dipswitch % 100) / 10;
    uint32_t ones = dipswitch % 10;
    gpio[0] = swap_u32((sevenSeg[hundreds] << 16) | (sevenSeg[tens] << 8) | sevenSeg[ones]);

#ifdef __WITH_CI
    for (int pixel = 0; pixel < ((camParams.nrOfLinesPerImage * camParams.nrOfPixelsPerLine) >> 2); pixel++) {
      uint32_t pixel1 = rgb[2 * pixel];
      uint32_t pixel2 = rgb[2 * pixel + 1];
      asm volatile ("l.nios_rrr %[out1], %[in1], %[in2], 0xC"
                    : [out1] "=r" (grayPixels)
                    : [in1] "r" (pixel1), [in2] "r" (pixel2));

      gray[0] = (grayPixels & 0xFF) > dipswitch ? 0xFF : 0;
      gray[1] = ((grayPixels >> 8) & 0xFF) > dipswitch ? 0xFF : 0;
      gray[2] = ((grayPixels >> 16) & 0xFF) > dipswitch ? 0xFF : 0;
      gray[3] = ((grayPixels >> 24) & 0xFF) > dipswitch ? 0xFF : 0;
      gray += 4;
    }
#else
    for (int line = 0; line < camParams.nrOfLinesPerImage; line++) {
      for (int pixel = 0; pixel < camParams.nrOfPixelsPerLine; pixel++) {
        uint16_t rgb = swap_u16(rgb565[line * camParams.nrOfPixelsPerLine + pixel]);
        uint32_t red = ((rgb >> 11) & 0x1F) << 3;
        uint32_t green = ((rgb >> 5) & 0x3F) << 2;
        uint32_t blue = (rgb & 0x1F) << 3;
        uint32_t grayVal = ((red * 54 + green * 183 + blue * 19) >> 8) & 0xFF;
        grayscale[line * camParams.nrOfPixelsPerLine + pixel] = grayVal;
      }
    }
#endif

    asm volatile ("l.nios_rrr %[out1], r0, %[in2], 0xC" : [out1] "=r" (cycles) : [in2] "r" (1 << 8 | 7 << 4));
    asm volatile ("l.nios_rrr %[out1], %[in1], %[in2], 0xC" : [out1] "=r" (stall) : [in1] "r" (1), [in2] "r" (1 << 9));
    asm volatile ("l.nios_rrr %[out1], %[in1], %[in2], 0xC" : [out1] "=r" (idle) : [in1] "r" (2), [in2] "r" (1 << 10));

    printf("nrOfCycles: %d %d %d\n", cycles, stall, idle);
  }
}