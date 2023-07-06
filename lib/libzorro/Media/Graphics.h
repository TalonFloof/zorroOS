#ifndef _LIBZORRO_MEDIA_GRAPHICS_H
#define _LIBZORRO_MEDIA_GRAPHICS_H
#include <stdint.h>
#include <stddef.h>

typedef struct {
    uint32_t* buf;
    int w;
    int h;
} GraphicsContext;

typedef struct {
  unsigned char magic[4];
  uint32_t version;
  uint32_t headerSize;
  uint32_t flags;
  uint32_t length;
  uint32_t charSize;
  uint32_t height;
  uint32_t width;
}__attribute__((packed)) PSFHeader;

typedef struct {
  uint32_t entrySize;
  uint16_t w;
  uint16_t h;
  uint16_t bpp;
  uint16_t reserved;
  uint32_t iconOffset;
  char name[];
}__attribute__((packed)) IconEntry;

GraphicsContext* Graphics_NewContext(uint32_t* buf, int w, int h);
void Graphics_DrawRect(GraphicsContext* context, int x, int y, int w, int h, uint32_t color);
void Graphics_DrawRectOutline(GraphicsContext* context, int x, int y, int w, int h, uint32_t color);
void Graphics_RenderMonoBitmap(GraphicsContext* context, unsigned int x, unsigned int y, unsigned int w, unsigned int h, 
                                  unsigned int scW, unsigned int scH, uint8_t* data, uint32_t color);
void Graphics_RenderGlyph(GraphicsContext* context, unsigned int x, unsigned int y, uint32_t color, PSFHeader* font, int scale, uint8_t glyph);
void Graphics_RenderString(GraphicsContext* context, unsigned int x, unsigned int y, uint32_t color, PSFHeader* font, int scale, char* str);
void Graphics_RenderCenteredString(GraphicsContext* context, unsigned int x, unsigned int y, uint32_t color, PSFHeader* font, int scale, char* str);
PSFHeader* Graphics_LoadFont(const char* name);
void* Graphics_LoadIconPack(const char* path);
void Graphics_RenderIcon(GraphicsContext* context, void* pack, const char* name, int x, int y, int w, int h, uint32_t tint);

#endif