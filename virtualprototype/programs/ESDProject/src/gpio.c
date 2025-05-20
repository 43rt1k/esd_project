#include <swap.h>
#include <stdio.h>

const uint8_t SEVEN_SEG[10] = {0x3F,0x06,0x5B,0x4F,0x66,0x6D,0x7D,0x07,0x7F,0x6F};

uint32_t gpio_get_DipSw(volatile unsigned int* gpio){
    return swap_u32(gpio[0]) ^ 0xFF;
}

void gpio_set_sevenSeg(volatile unsigned int* gpio, uint32_t value){
    uint32_t hundreds = value / 100;
    uint32_t tens = (value % 100) / 10;
    uint32_t ones = value % 10;
    gpio[0] = swap_u32((SEVEN_SEG[hundreds] << 16) | (SEVEN_SEG[tens] << 8) | SEVEN_SEG[ones]);
}
















