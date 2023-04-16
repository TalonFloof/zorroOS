#define _FB_IMPL
#include <Graphics/Framebuffer.h>
#include <Utilities/String.h>

uint8_t* fbPtr;
uint16_t fbWidth;
uint16_t fbHeight;
uint8_t fbBpp;

void Framebuffer_DrawRect(int x, int y, int w, int h, uint32_t color) {
  int i, j;
  for(i=y;i<y+h;i++) {
    for(j=x;j<x+w;j++) {
      ((uint32_t*)fbPtr)[(i*fbWidth)+j] = color;
    }
  }
}

void Framebuffer_Clear(uint32_t color) {
  int i;
  for(i=0;i<fbWidth*fbHeight;i++) {
    ((uint32_t*)fbPtr)[i] = color;
  }
}

void Framebuffer_RenderMonoBitmap(unsigned int x, unsigned int y, unsigned int w, unsigned int h, 
                                  unsigned int scW, unsigned int scH, uint8_t* data, uint32_t color) {
  uint32_t x_ratio = ((w<<16)/scW)+1;
  uint32_t y_ratio = ((h<<16)/scH)+1;
  uint32_t i,j;
  for(i=0;i<scH;i++) {
    for(j=0;j<scW;j++) {
      uint32_t finalX = ((j*x_ratio)>>16);
      uint32_t finalY = ((i*y_ratio)>>16);
      uint32_t index = (finalY*w)+finalX;
      uint8_t dat = data[index/8];
      if((dat >> (7-(index%8))) & 1) {
        ((uint32_t*)fbPtr)[((i+y)*fbWidth)+(j+x)] = color;
      }
    }
  }
}

void Framebuffer_RenderGlyph(unsigned int x, unsigned int y, uint32_t color, PSFHeader* font, uint8_t glyph) {
  uint8_t* img = ((uint8_t*)font)+((font->headerSize)+((glyph-0x20)*(font->charSize)));
  uint32_t width = (font->charSize/font->height)*8;
  Framebuffer_RenderMonoBitmap(x,y,width,font->height,width,font->height,img,color);
}

void Framebuffer_RenderString(unsigned int x, unsigned int y, uint32_t color, PSFHeader* font, char* str) {
  int i;
  int len = strlen(str);
  for(i=0;i < len;i++) {
    Framebuffer_RenderGlyph(x+(font->width*i),y,color,font,str[i]);
  }
}