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

void Framebuffer_RenderMonochromeBitmap(IZorroFramebuffer *fb, int x, int y, int w, int h, int scale, uint32_t color, uint64_t line_size, uint8_t *ptr)
{
    int i, j;
    for (i = 0; i < h; i++)
    {
        for (j = 0; j < w; j++)
        {
            uint64_t byte_offset = (i * line_size) + (j / 8);
            uint64_t bit_offset = j % 8;
            uint8_t dat = ptr[byte_offset];
            if (dat & (1 << (7 - bit_offset)) != 0)
            {
                Framebuffer_Rect(x + (j * scale), y + (i * scale), scale, scale, color);
            }
        }
    }
}