#ifndef _RAVEN_RAVEN_H
#define _RAVEN_RAVEN_H
#include <stdint.h>

typedef struct {
    uint32_t width;
    uint32_t height;
    uint32_t pitch;
    uint32_t bpp;
    uint32_t* addr;
    uint32_t* back;
} FBInfo;

typedef struct {
    void* prev;
    void* next;
    int64_t id;
    int x;
    int y;
    unsigned int w;
    unsigned int h;
    unsigned char flags;
    uint32_t* backBuf;
    uint32_t* frontBuf;
    int64_t owner;
} Window;

#define FLAG_OPAQUE 1
#define FLAG_NOMOVE 2
#define FLAG_ACRYLIC 4

void Redraw(int x, int y, int w, int h);

#ifndef _RAVEN_IMPL
extern FBInfo fbInfo;
extern Window cursorWin;
extern Window* winHead;
extern Window* winTail;
#endif

#endif