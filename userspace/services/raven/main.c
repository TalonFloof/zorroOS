#include <System/Thread.h>
#include <System/Syscall.h>
#include <System/SharedMemory.h>
#include <Filesystem/Filesystem.h>
#include <Filesystem/MQueue.h>
#include <Common/Alloc.h>
#include <Common/String.h>
#include <Media/QOI.h>
#include <Media/Image.h>
#include <Media/StackBlur.h>
#include <Common/Spinlock.h>
#include "kbd.h"
#include "mouse.h"
#define _RAVEN_IMPL
#include "raven.h"

#define MIN(__x, __y) ((__x) < (__y) ? (__x) : (__y))
#define MAX(__x, __y) ((__x) > (__y) ? (__x) : (__y))

FBInfo fbInfo;
MQueue* msgQueue = NULL;

Window* winHead = NULL;
Window* winTail = NULL;
char windowLock = 0;
uint64_t nextWinID = 1;
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
    .shmID = 0,
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
    .shmID = 0,
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
    SpinlockAcquire(&windowLock);
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
          if((win->flags & FLAG_ACRYLIC)) {
            StackBlur(fbInfo.back,fbInfo.pitch/(fbInfo.bpp/8),4,MAX(1,fX1),MIN(fbInfo.width-1,fX2),MAX(1,fY1),MIN(fbInfo.height-1,fY2));
          }
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
                    fbInfo.back[(i*(fbInfo.pitch/bytes))+j] = pixel;
                    fbInfo.addr[(i*(fbInfo.pitch/bytes))+j] = pixel;
                } else if (((pixel & 0xFF000000) != 0x00000000 && (win->flags & FLAG_OPAQUE) == 0) || (win->flags & FLAG_ACRYLIC)) {
                    uint32_t result = BlendPixel(fbInfo.back[(i*(fbInfo.pitch/bytes))+j],pixel);
                    fbInfo.back[(i*(fbInfo.pitch/bytes))+j] = result;
                    fbInfo.addr[(i*(fbInfo.pitch/bytes))+j] = result;
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
    SpinlockRelease(&windowLock);
}

void MoveWinToFront(Window* win) {
    SpinlockAcquire(&windowLock);
    if(winTail == win) {
        SpinlockRelease(&windowLock);
        return;
    }
    if(winHead == win) {
        winHead = win->next;
    }
    if(win->prev != NULL) {
        ((Window*)win->prev)->next = win->next;
    }
    if(win->next != NULL) {
        ((Window*)win->next)->prev = win->prev;
    }
    winTail->next = win;
    win->prev = winTail;
    win->next = NULL;
    winTail = win;
    SpinlockRelease(&windowLock);
}

Window* GetWindowByID(int64_t id) {
    Window* index = winTail;
    while(index != NULL) {
        if(index->id == id) {
            return index;
        }
        index = index->prev;
    }
    return NULL;
}

void LoadBackground(const char* name) {
    qoi_desc desc;
    void* bgImage = qoi_read(name,&desc,4);
    if(bgImage == NULL) {
        RyuLog("RAVEN WARN: Failed to load image ");
        RyuLog(name);
        RyuLog("!\n");
        return;
    }
    Image_ABGRToARGB((uint32_t*)bgImage,desc.width*desc.height);
    Image_ScaleNearest((uint32_t*)bgImage,backgroundWin.frontBuf,desc.width,desc.height,backgroundWin.w,backgroundWin.h);
    free(bgImage);
    Redraw(0,0,fbInfo.width,fbInfo.height);
}

int main() {
    OpenedFile fbFile;
    if(Open("/dev/fb0",O_RDWR,&fbFile) < 0) {
        RyuLog("Failed to open /dev/fb0!\n");
        return 1;
    }
    fbFile.IOCtl(&fbFile,0x100,&fbInfo);
    backgroundWin.w = fbInfo.width;
    backgroundWin.h = fbInfo.height;
    backgroundWin.frontBuf = (uint32_t*)MMap(NULL,fbInfo.width*fbInfo.height*4,3,MAP_PRIVATE|MAP_ANONYMOUS,-1,0);
    fbInfo.back = (uint32_t*)MMap(NULL,fbInfo.pitch*fbInfo.height,3,MAP_PRIVATE|MAP_ANONYMOUS,-1,0);
    fbInfo.addr = MMap(NULL,fbInfo.pitch*fbInfo.height,3,MAP_SHARED,fbFile.fd,0);
    fbFile.Close(&fbFile);
    void* kbdStack = MMap(NULL,0x8000,3,MAP_PRIVATE|MAP_ANONYMOUS,-1,0);
    uintptr_t kbdThr = NewThread("Raven Keyboard Thread",&KeyboardThread,(void*)(((uintptr_t)kbdStack)+0x8000));
    void* mouseStack = MMap(NULL,0x8000,3,MAP_PRIVATE|MAP_ANONYMOUS,-1,0);
    uintptr_t mouseThr = NewThread("Raven Mouse Thread",&MouseThread,(void*)(((uintptr_t)mouseStack)+0x8000));
    msgQueue = MQueue_Bind("/dev/mqueue/Raven");
    LoadBackground("/System/Wallpapers/Autumn.qoi");
    Redraw(0,0,fbInfo.width,fbInfo.height);
    while(1) {
        int64_t teamID;
        RavenPacket* packet = MQueue_RecieveFromClient(msgQueue,&teamID,NULL);
        switch(packet->type) {
            case RAVEN_CREATE_WINDOW: {
                SpinlockAcquire(&windowLock);
                Window* win = malloc(sizeof(Window));
                win->id = nextWinID++;
                win->owner = teamID;
                if(winTail != NULL) {
                    winTail->next = win;
                }
                win->prev = winTail;
                win->next = NULL;
                win->w = packet->create.w;
                win->h = packet->create.h;
                win->flags = packet->create.flags;
                win->x = (fbInfo.width/2)-(packet->create.w/2);
                win->y = (fbInfo.height/2)-(packet->create.h/2);
                win->shmID = NewSharedMemory((win->w*win->h)*4);
                win->backBuf = MapSharedMemory(win->shmID);
                win->frontBuf = malloc((win->w*win->h)*4);
                winTail = win;
                if(winHead == NULL) {
                    winHead = win;
                }
                RavenCreateWindowResponse response;
                response.id = win->id;
                response.backBuf = win->shmID;
                MQueue_SendToClient(msgQueue,teamID,&response,sizeof(RavenCreateWindowResponse));
                SpinlockRelease(&windowLock);
                Redraw(win->x,win->y,win->w,win->h);
                break;
            }
            case RAVEN_FLIP_BUFFER: {
                SpinlockAcquire(&windowLock);
                Window* win = GetWindowByID(packet->flipBuffer.id);
                if(win != NULL) {
                    for(int i=packet->flipBuffer.y; i < packet->flipBuffer.y+packet->flipBuffer.h; i++) {
                        memcpy(&win->frontBuf[(i*win->w)+packet->flipBuffer.x],&win->backBuf[(i*win->w)+packet->flipBuffer.x],packet->flipBuffer.w*4);
                    }
                }
                SpinlockRelease(&windowLock);
                Redraw(win->x+packet->flipBuffer.x,win->y+packet->flipBuffer.y,packet->flipBuffer.w,packet->flipBuffer.h);
                break;
            }
            default: {
                break;
            }
        }
        free(packet);
    }
    return 0;
}