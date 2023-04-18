#pragma once
#include <stdint.h>

typedef struct {
    void* prev;
    void* next;
    uint16_t x;
    uint16_t y;
    uint16_t w;
    uint16_t h;
    uint32_t* data;
} Window;

void Compositor_WindowSetup();