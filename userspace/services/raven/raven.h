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
    int64_t creator;
    int64_t owner;
} Window;

typedef struct {
    void* prev;
    void* next;
    const char* icon;
    const char* path;
    char pressed;
} DockItem;

void Redraw(int x, int y, int w, int h);
void MoveWinToFront(Window* win);
void invertPixel(int x, int y);
void renderInvertOutline(int x, int y, int w, int h);
void DoBoxAnimation(int x1, int y1, int w1, int h1, int x2, int y2, int w2, int h2, char expand);
void RedrawDock();

#ifndef _RAVEN_IMPL
extern MQueue* msgQueue;
extern FBInfo fbInfo;
extern char windowLock;
extern Window cursorWin;
extern Window* winFocus;
extern Window* winHead;
extern Window* winTail;
extern Window dockWin;
extern DockItem* dockHead;
extern DockItem* dockTail;
#endif

#endif