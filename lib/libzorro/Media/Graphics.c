#include "Graphics.h"
#include <Common/Alloc.h>
#include <Filesystem/Filesystem.h>
#include <Common/String.h>

GraphicsContext* Graphics_NewContext(uint32_t* buf, int w, int h) {
    GraphicsContext* context = malloc(sizeof(GraphicsContext));
    context->buf = buf;
    context->w = w;
    context->h = h;
    return context;
}

void Graphics_DrawRect(GraphicsContext* context, int x, int y, int w, int h, uint32_t color) {
    for(int i = y; i < y+h; i++) {
        if(i < 0 || i >= context->h) {
            return;
        }
        for(int j = x; j < x+w; j++) {
            if(j < 0 || j >= context->w) {
                break;
            }
            context->buf[(i*context->w)+j] = color;
        }
    }
}

void Graphics_RenderMonoBitmap(GraphicsContext* context, unsigned int x, unsigned int y, unsigned int w, unsigned int h, 
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
                Graphics_DrawRect(context,j+x,i+y,1,1,color);
            }
        }
    }
}

void Graphics_RenderGlyph(GraphicsContext* context, unsigned int x, unsigned int y, uint32_t color, PSFHeader* font, int scale, uint8_t glyph) {
    uint8_t* img = ((uint8_t*)font)+((font->headerSize)+((glyph-0x20)*(font->charSize)));
    uint32_t width = (font->charSize/font->height)*8;
    Graphics_RenderMonoBitmap(context, x,y,width,font->height,width*scale,font->height*scale,img,color);
}

void Graphics_RenderString(GraphicsContext* context, unsigned int x, unsigned int y, uint32_t color, PSFHeader* font, int scale, char* str) {
    int i;
    int len = strlen(str);
    for(i=0;i < len;i++) {
        Graphics_RenderGlyph(context, x+((font->width*scale)*i),y,color,font,scale,str[i]);
    }
}
void Graphics_RenderCenteredString(GraphicsContext* context, unsigned int x, unsigned int y, uint32_t color, PSFHeader* font, int scale, char* str) {
    Graphics_RenderString(context,x-((strlen(str)*((font->width*scale)))/2),y,color,font,scale,str);
}

PSFHeader* Graphics_LoadFont(const char* name) {
    OpenedFile file;
    if(Open(name,O_RDONLY,&file) < 0) {
        return NULL;
    }
    size_t size = file.LSeek(&file,0,SEEK_END);
    file.LSeek(&file,0,SEEK_SET);
    PSFHeader* font = malloc(size);
    file.Read(&file,font,size);
    file.Close(&file);
    return font;
}

void* Graphics_LoadIconPack(const char* path) {
    OpenedFile file;
    if(Open(path,O_RDONLY,&file) < 0) {
        return NULL;
    }
    size_t size = file.LSeek(&file,0,SEEK_END);
    file.LSeek(&file,0,SEEK_SET);
    void* pack = malloc(size);
    file.Read(&file,pack,size);
    file.Close(&file);
    return pack;
}

void Graphics_RenderIcon(GraphicsContext* context, void* pack, const char* name, int x, int y, int w, int h, uint32_t tint) {
    IconEntry* entry = pack;
    while(entry->entrySize != 0) {
        if(strcmp((const char*)&entry->name,name) == 0) {
            if(entry->bpp == 1) {
                Graphics_RenderMonoBitmap(context,x,y,entry->w,entry->h,w,h,(uint8_t*)(((uintptr_t)pack)+entry->iconOffset),tint);
            }
            break;
        }
        entry = (IconEntry*)(((uintptr_t)entry)+entry->entrySize);
    }
}