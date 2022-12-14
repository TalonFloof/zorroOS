#include "framebuffer.h"

void Framebuffer_Rect(IZorroFramebuffer *fb, int x, int y, int w, int h, uint32_t color)
{
    int i, j;
    for (i = y; i < y + h; i++)
    {
        for (j = x; j < x + w; j++)
        {
            fb->set(j, i, color);
        }
    }
}

void Framebuffer_Clear(IZorroFramebuffer *fb, uint32_t color)
{
    Framebuffer_Rect(fb, 0, 0, fb->resolution[0], fb->resolution[1], color);
}