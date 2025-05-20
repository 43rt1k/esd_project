#ifndef GPIO_H
#define GPIO_H

#include <stdint.h>
#include <ov7670.h>

extern const uint8_t SEVEN_SEG[10];

uint32_t gpio_get_DipSw(volatile unsigned int* gpio);
void gpio_set_sevenSeg(volatile unsigned int* gpio, uint32_t value);

#endif 

