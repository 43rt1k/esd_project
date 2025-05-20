// sobel.h
#ifndef PROFILING_H
#define PROFILING_H

#include <stdint.h>
#include <ov7670.h>

#define NIOS_INSTR      "l.nios_rrr"
#define CI_ID_profileCi "0x0B"

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

#define COUNTER_SELECT_0_profileCi 0
#define COUNTER_SELECT_1_profileCi 1
#define COUNTER_SELECT_2_profileCi 2
#define COUNTER_SELECT_3_profileCi 3

#define COUNTER_ENABLE_3_profileCi    (1 << EC_3)
#define COUNTER_ENABLE_012_profileCi  ((1 << EC_0) | (1 << EC_1) | (1 << EC_2))
#define COUNTER_ENABLE_0123_profileCi ((1 << EC_0) | (1 << EC_1) | (1 << EC_2) | (1 << EC_3))
#define COUNTER_DISABLE_012_profileCi ((1 << DC_0) | (1 << DC_1) | (1 << DC_2))
#define COUNTER_RESET_0_profileCi     (1 << RC_0)
#define COUNTER_RESET_1_profileCi     (1 << RC_1)
#define COUNTER_RESET_2_profileCi     (1 << RC_2)
#define COUNTER_RESET_0123_profileCi  ((1 << RC_0) | (1 << RC_1) | (1 << RC_2) | (1 << RC_3))


typedef struct {
    volatile uint32_t cycles;
    volatile uint32_t stall;
    volatile uint32_t idle;
    volatile uint32_t totalCycles;
} ProfilingStatus;

void asm_reset_profiling();
void asm_enable_profiling_counters();
void asm_read_profiling(volatile ProfilingStatus* profData, uint8_t ifPrintProf);

#endif 

