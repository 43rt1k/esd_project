#include "profiling.h"
#include <stdio.h>

void asm_reset_profiling() {
    asm volatile (NIOS_INSTR " r0,r0,%[in2]," CI_ID_profileCi :: [in2] "r"(COUNTER_RESET_0123_profileCi | COUNTER_ENABLE_3_profileCi));
}

void asm_enable_profiling_counters() {
    asm volatile (NIOS_INSTR " r0,r0,%[in2]," CI_ID_profileCi :: [in2] "r"(COUNTER_ENABLE_012_profileCi));
}

void asm_read_profiling(volatile ProfilingStatus* profData, uint8_t ifPrintProf) {
    asm volatile (NIOS_INSTR " %[out1],%[in1],%[in2]," CI_ID_profileCi : [out1] "=r" (profData->cycles) : [in1] "r" (COUNTER_SELECT_0_profileCi), [in2] "r" (COUNTER_DISABLE_012_profileCi | COUNTER_RESET_0_profileCi));
    asm volatile (NIOS_INSTR " %[out1],%[in1],%[in2]," CI_ID_profileCi : [out1] "=r" (profData->stall)  : [in1] "r" (COUNTER_SELECT_1_profileCi), [in2] "r" (COUNTER_RESET_1_profileCi));
    asm volatile (NIOS_INSTR " %[out1],%[in1],%[in2]," CI_ID_profileCi : [out1] "=r" (profData->idle)   : [in1] "r" (COUNTER_SELECT_2_profileCi), [in2] "r" (COUNTER_RESET_2_profileCi));
    asm volatile (NIOS_INSTR " %[out1],%[in1],r0," CI_ID_profileCi : [out1] "=r" (profData->totalCycles) : [in1] "r" (COUNTER_SELECT_3_profileCi));

    if (ifPrintProf) {
        printf("Cycles: %u | Stall: %u | Idle: %u\n", profData->cycles, profData->stall, profData->idle);
    }
}
