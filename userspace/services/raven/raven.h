#ifndef _RAVEN_RAVEN_H
#define _RAVEN_RAVEN_H
#include <stdint.h>
#include <Raven/Raven.h>

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
    int w;
    int h;
    unsigned char flags;
    int64_t shmID;
    uint32_t* backBuf;
    uint32_t* frontBuf;
    int64_t owner;
} Window;

void Redraw(int x, int y, int w, int h);
void MoveWinToFront(Window* win);

#ifndef _RAVEN_IMPL
extern MQueue* msgQueue;
extern FBInfo fbInfo;
extern char windowLock;
extern Window cursorWin;
extern Window* winFocus;
extern Window* winHead;
extern Window* winTail;
extern Window* iconHead;
extern Window* iconTail;
#endif

#endif