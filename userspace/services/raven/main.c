#include <System/Thread.h>
#include <System/Syscall.h>
#include <Filesystem/Filesystem.h>
#include <Filesystem/MQueue.h>
#include <Common/Alloc.h>
#include <Common/String.h>
#include <Media/QOI.h>
#include <Media/ImageScale.h>
#include "kbd.h"
#include "mouse.h"

#define MIN(__x, __y) ((__x) < (__y) ? (__x) : (__y))
#define MAX(__x, __y) ((__x) > (__y) ? (__x) : (__y))

typedef struct {
    uint32_t width;
    uint32_t height;
    uint32_t pitch;
    uint32_t bpp;
    uint32_t* addr;
} FBInfo;

FBInfo fbInfo;

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

Window* winHead = NULL;
Window* winTail = NULL;
const uint32_t cursorBuf[10*16] = {
    0xffffffff,0xffffffff,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,
    0xffffffff,0xff000000,0xffffffff,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,
    0xffffffff,0xff000000,0xff000000,0xffffffff,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,
    0xffffffff,0xff000000,0xff000000,0xff000000,0xffffffff,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,
    0xffffffff,0xff000000,0xff000000,0xff000000,0xff000000,0xffffffff,0x00000000,0x00000000,0x00000000,0x00000000,
    0xffffffff,0xff000000,0xff000000,0xff000000,0xff000000,0xff000000,0xffffffff,0x00000000,0x00000000,0x00000000,
    0xffffffff,0xff000000,0xff000000,0xff000000,0xff000000,0xff000000,0xff000000,0xffffffff,0x00000000,0x00000000,
    0xffffffff,0xff000000,0xff000000,0xff000000,0xff000000,0xff000000,0xff000000,0xff000000,0xffffffff,0x00000000,
    0xffffffff,0xff000000,0xff000000,0xff000000,0xff000000,0xff000000,0xff000000,0xff000000,0xff000000,0xffffffff,
    0xffffffff,0xff000000,0xff000000,0xff000000,0xff000000,0xff000000,0xffffffff,0xffffffff,0xffffffff,0xffffffff,
    0xffffffff,0xff000000,0xff000000,0xffffffff,0xff000000,0xff000000,0xffffffff,0x00000000,0x00000000,0x00000000,
    0xffffffff,0xff000000,0xffffffff,0x00000000,0xffffffff,0xff000000,0xff000000,0xffffffff,0x00000000,0x00000000,
    0xffffffff,0xffffffff,0x00000000,0x00000000,0xffffffff,0xff000000,0xff000000,0xffffffff,0x00000000,0x00000000,
    0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0xffffffff,0xff000000,0xff000000,0xffffffff,0x00000000,
    0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0xffffffff,0xff000000,0xff000000,0xffffffff,0x00000000,
    0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0xffffffff,0xffffffff,0xffffffff,0x00000000,
};
Window backgroundWin = (Window){
    .prev = NULL,
    .next = NULL,
    .id = 0,
    .x = 0,
    .y = 0,
    .w = 0,
    .h = 0,
    .flags = FLAG_NOMOVE | FLAG_OPAQUE,
    .backBuf = NULL,
    .frontBuf = NULL,
    .owner = 0,
};
Window cursorWin = (Window){
    .prev = NULL,
    .next = NULL,
    .id = 0,
    .x = 0,
    .y = 0,
    .w = 10,
    .h = 16,
    .flags = FLAG_NOMOVE,
    .backBuf = NULL,
    .frontBuf = (uint32_t*)&cursorBuf,
    .owner = 0,
};

uint32_t BlendPixel(uint32_t px1, uint32_t px2) {
    uint32_t m1 = (px2 & 0xFF000000) >> 24;
    uint32_t m2 = 255 - m1;
    uint32_t r2 = m2 * (px1 & 0x00FF00FF);
    uint32_t g2 = m2 * (px1 & 0x0000FF00);
    uint32_t r1 = m1 * (px2 & 0x00FF00FF);
    uint32_t g1 = m1 * (px2 & 0x0000FF00);
    uint32_t result = (0x0000FF00 & ((g1 + g2) >> 8)) | (0x00FF00FF & ((r1 + r2) >> 8));
    return result;
}

void Redraw(int x, int y, int w, int h) {
    Window* win = &backgroundWin;
    int max_x, max_y;
    max_x = x+(w-1);
    max_y = y+(h);
    while(win != NULL) {
        if(!(max_x <= win->x || max_y <= win->y || x >= (win->x+win->w) || y >= (win->y+win->h))) {
          int fX1, fX2, fY1, fY2;
          fX1 = MAX(x,win->x);
          fX2 = MIN(max_x,win->x+(win->w-1));
          fY1 = MAX(y,win->y);
          fY2 = MIN(max_y,win->y+(win->h-1));
          int bytes = fbInfo.bpp/8;
          for(int i=fY1; i <= fY2; i++) {
            if(i < 0) {
                continue;
            } else if(i >= fbInfo.height) {
                break;
            }
            for(int j=fX1; j <= fX2; j++) {
                if(j < 0) {
                    continue;
                } else if(j >= fbInfo.width) {
                    break;
                }
                uint32_t pixel = win->frontBuf[((i - win->y)*win->w)+(j-win->x)];
                if ((pixel & 0xFF000000) == 0xFF000000 || (win->flags & FLAG_OPAQUE) != 0) {
                    fbInfo.addr[(i*(fbInfo.pitch/bytes))+j] = pixel;
                }
            }
          }
        }
        if(win == &backgroundWin) {
            if(winHead == NULL) {
                win = &cursorWin;
            } else {
                win = winHead;
            }
        } else if(win == winTail) {
            win = &cursorWin;
        } else {
            win = win->next;
        }
    }
}

void LoadBackground(const char* name) {
    qoi_desc desc;
    void* bgImage = qoi_read(name,&desc,4);
}

int main() {
    OpenedFile fbFile;
    if(Open("/dev/fb0",O_RDWR,&fbFile) < 0) {
        RyuLog("Failed to open /dev/fb0!\n");
        return 1;
    }
    fbFile.IOCtl(&fbFile,0x100,&fbInfo);
    fbInfo.addr = MMap(NULL,fbInfo.pitch*fbInfo.height,3,MAP_SHARED,fbFile.fd,0);
    fbFile.Close(&fbFile);
    void* kbdStack = MMap(NULL,0x4000,3,MAP_PRIVATE|MAP_ANONYMOUS,-1,0);
    uintptr_t kbdThr = NewThread("Raven Keyboard Thread",&KeyboardThread,(void*)(((uintptr_t)kbdStack)+0x3ff8));
    void* mouseStack = MMap(NULL,0x4000,3,MAP_PRIVATE|MAP_ANONYMOUS,-1,0);
    uintptr_t mouseThr = NewThread("Raven Mouse Thread",&MouseThread,(void*)(((uintptr_t)mouseStack)+0x3ff8));
    backgroundWin.frontBuf = (uint32_t*)malloc((fbInfo.width*fbInfo.height)*(fbInfo.bpp/8));
    Redraw(0,0,fbInfo.width,fbInfo.height);
    while(1) {
    }
    return 0;
}