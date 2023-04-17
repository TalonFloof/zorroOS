#pragma once
#include <stdint.h>

typedef struct {
    uint16_t isrLow;
    uint16_t kernelCS;
    uint8_t reserved;
    uint8_t attributes;
    uint16_t isrMid;
    uint32_t isrHigh;
    uint32_t zero;
} __attribute__((packed)) IDTEntry;

typedef struct {
    uint16_t limit;
    uint64_t base;
} __attribute__((packed)) IDTP;

void IDT_Initialize();