#pragma once
#include <stdint.h>



typedef struct {
    void* prev;
    void* next;
    uint16_t x;
    uint16_t y;
    uint16_t w;
    uint16_t h;
    uint32_t flags;
    uint32_t* backBuffer;
    uint32_t* frontBuffer;
} Window;

extern Window* windowHead;
extern Window* windowTail;

void Compositor_WindowRedraw(int x, int y, int w, int h);
void Compositor_WindowSetup();