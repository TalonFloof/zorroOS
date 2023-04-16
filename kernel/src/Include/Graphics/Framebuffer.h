#pragma once
#include <stdint.h>
#include <Graphics/PSF.h>

#ifndef _FB_IMPL
extern uint8_t* fbPtr;
extern uint16_t fbWidth;
extern uint16_t fbHeight;
extern uint8_t fbBpp;
#endif

void Framebuffer_DrawRect(int x, int y, int w, int h, uint32_t color);
void Framebuffer_Clear(uint32_t color);
void Framebuffer_RenderMonoBitmap(unsigned int x, unsigned int y, unsigned int w, unsigned int h, 
                                  unsigned int scW, unsigned int scH, uint8_t* data, uint32_t color);
void Framebuffer_RenderGlyph(unsigned int x, unsigned int y, uint32_t color, PSFHeader* font, uint8_t glyph);
void Framebuffer_RenderString(unsigned int x, unsigned int y, uint32_t color, PSFHeader* font, char* str);