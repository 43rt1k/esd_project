#ifndef CAMERA_H
#define CAMERA_H

#include <stdint.h>
#include <ov7670.h>

#define IMAGE_SIZE (640*480)

#define NIOS_INSTR      "l.nios_rrr"
#define CI_ID_rgb565ISE "0x11"
#define CI_ID_sobel     "0x12"
#define CI_ID_gaussian  "0x13"

#define SOBEL_P0_LO  0
#define SOBEL_P1_LO  8
#define SOBEL_P2_LO 16
#define SOBEL_P3_LO 24
#define SOBEL_P5_LO  0
#define SOBEL_P6_LO  8
#define SOBEL_P7_LO 16
#define SOBEL_P8_LO 24

extern const uint8_t SEVEN_SEG[10];

void cam_init(camParameters* camParams, unsigned int* vga, volatile uint32_t* result, volatile uint8_t* camOutput);
void cam_rgb_2_gray(camParameters* camParams, volatile uint16_t* rgb565, volatile uint8_t* grayScale);

uint32_t asm_rgb_2_gray(uint32_t pixel1, uint32_t pixel2);
void asm_sobel(const camParameters* camParams, volatile uint8_t* grayScale, volatile uint8_t* sobelOutput);
void asm_gaussian(const camParameters* camParams, volatile uint8_t* grayScale, volatile uint8_t* blurOutput);
#endif 

