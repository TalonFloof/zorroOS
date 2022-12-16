#include <arch/interfaces/framebuffer.h>
#include <arch/interfaces/zorro_script.h>
#include <util/string.h>

void Framebuffer_Rect(IOwlFramebuffer *fb, int x, int y, int w, int h, uint32_t color)
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

void Framebuffer_Clear(IOwlFramebuffer *fb, uint32_t color)
{
    Framebuffer_Rect(fb, 0, 0, fb->resolution[0], fb->resolution[1], color);
}

void Framebuffer_RenderMonochromeBitmap(IOwlFramebuffer *fb, int x, int y, int w, int h, int scale, uint32_t color, uint64_t line_size, uint8_t *ptr)
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
                Framebuffer_Rect(fb, x + (j * scale), y + (i * scale), scale, scale, color);
            }
        }
    }
}

void Framebuffer_RenderRune(IOwlFramebuffer *fb, int x, int y, int scale, uint32_t color, uint8_t rune)
{
    Framebuffer_RenderMonochromeBitmap(fb, x, y, 8, 16, scale, color, 1, (uint8_t *)(((uint64_t)&zorro_script) + ((uint64_t)rune * 16)));
}

void Framebuffer_RenderText(IOwlFramebuffer *fb, int x, int y, int scale, uint32_t color, const char *string)
{
    int i;
    for (i = 0; string[i] != 0; i++)
    {
        Framebuffer_RenderRune(fb, x + (i * (8 * scale)), y, scale, color, string[i]);
    }
}

void Framebuffer_RenderCenteredText(IOwlFramebuffer *fb, int center_x, int y, int scale, uint32_t color, const char *string)
{
    Framebuffer_RenderText(fb, center_x - ((strlen(string) * (8 * scale)) / 2), y, scale, color, string);
}