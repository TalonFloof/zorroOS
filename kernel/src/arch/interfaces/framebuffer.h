#ifndef _OWL_IFRAMEBUFFER_H
#define _OWL_IFRAMEBUFFER_H 1

#include <stdint.h>

typedef uint32_t (*IOwlFramebuffer_Get)(int, int);
typedef void (*IOwlFramebuffer_Set)(int, int, uint32_t);

typedef struct {
  uint64_t signature; /* "IOwlFrBf", or 0x42466f72726f5a49 */
  int resolution[2];
  uint8_t depth;
  void *pointer;
  IOwlFramebuffer_Get get;
  IOwlFramebuffer_Set set;
} IOwlFramebuffer;

void Framebuffer_Rect(IOwlFramebuffer *fb, int x, int y, int w, int h, uint32_t color);
void Framebuffer_Clear(IOwlFramebuffer *fb, uint32_t color);
void Framebuffer_RenderMonochromeBitmap(IOwlFramebuffer *fb, int x, int y, int w, int h, int scale, uint32_t color, uint64_t line_size, uint8_t *ptr);
void Framebuffer_RenderRune(IOwlFramebuffer *fb, int x, int y, int scale, uint32_t color, uint8_t rune);
void Framebuffer_RenderText(IOwlFramebuffer *fb, int x, int y, int scale, uint32_t color, const char *string);
void Framebuffer_RenderCenteredText(IOwlFramebuffer *fb, int center_x, int y, int scale, uint32_t color, const char *string);

#endif