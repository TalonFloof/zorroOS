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
#include <Raven/UI.h>
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
Window* winFocus = NULL;
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
Window dockWin = (Window){
    .prev = NULL,
    .next = NULL,
    .id = 0,
    .x = 0,
    .y = 0,
    .w = 0,
    .h = 0,
    .flags = FLAG_NOMOVE,
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
    max_x = x+w;
    max_y = y+h;
    int bytes = fbInfo.bpp/8;
    while(win != NULL) {
        if(!(max_x <= win->x || max_y <= win->y || x >= (win->x+win->w) || y >= (win->y+win->h))) {
          int fX1, fX2, fY1, fY2;
          fX1 = MAX(x,win->x);
          fX2 = MIN(max_x,win->x+(win->w-1));
          fY1 = MAX(y,win->y);
          fY2 = MIN(max_y,win->y+(win->h-1));
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
                } else if (((pixel & 0xFF000000) != 0x00000000 && (win->flags & FLAG_OPAQUE) == 0) || (win->flags & FLAG_ACRYLIC)) {
                    uint32_t result = BlendPixel(fbInfo.back[(i*(fbInfo.pitch/bytes))+j],pixel);
                    fbInfo.back[(i*(fbInfo.pitch/bytes))+j] = result;
                }
            }
          }
        }
        if(win == &backgroundWin) {
            if(winHead == NULL) {
                win = &dockWin;
            } else {
                win = winHead;
            }
        } else if(win == &dockWin) {
            win = &cursorWin;
        } else if(win == winTail) {
            win = &dockWin;
        } else {
            win = win->next;
        }
    }
    for(int i=y; i < y+h; i++) {
        if(i < 0) {
            continue;
        } else if(i >= fbInfo.height) {
            break;
        }
        memcpy(&fbInfo.addr[(i*(fbInfo.pitch/bytes))+x],&fbInfo.back[(i*(fbInfo.pitch/bytes))+x],w*4);
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
    if(winHead == NULL) {
        winHead = win;
    }
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

void invertPixel(int x, int y) {
    if(x >= 0 && x < fbInfo.width && y >= 0 && y < fbInfo.height) {
        fbInfo.addr[(y*(fbInfo.pitch/(fbInfo.bpp/8)))+x] = ~fbInfo.addr[(y*(fbInfo.pitch/(fbInfo.bpp/8)))+x];
    }
}

void renderInvertOutline(int x, int y, int w, int h) {
    for(int i=x+5; i < x+(w-5); i++) {
        invertPixel(i,y);
        invertPixel(i,y+(h-1));
    }
    for(int i=y+5; i < y+(h-5); i++) {
        invertPixel(x,i);
        invertPixel(x+(w-1),i);
    }
    // Top Left
    invertPixel(x+3,y+1);
    invertPixel(x+4,y+1);
    invertPixel(x+2,y+2);
    invertPixel(x+1,y+3);
    invertPixel(x+1,y+4);
    // Top Right
    invertPixel((x+w)-5,y+1);
    invertPixel((x+w)-4,y+1);
    invertPixel((x+w)-3,y+2);
    invertPixel((x+w)-2,y+3);
    invertPixel((x+w)-2,y+4);
    // Bottom Left
    invertPixel(x+3,(y+h)-2);
    invertPixel(x+4,(y+h)-2);
    invertPixel(x+2,(y+h)-3);
    invertPixel(x+1,(y+h)-4);
    invertPixel(x+1,(y+h)-5);
    // Bottom Right
    invertPixel((x+w)-5,(y+h)-2);
    invertPixel((x+w)-4,(y+h)-2);
    invertPixel((x+w)-3,(y+h)-3);
    invertPixel((x+w)-2,(y+h)-4);
    invertPixel((x+w)-2,(y+h)-5);
}

void DoBoxAnimation(int x1, int y1, int w1, int h1, int x2, int y2, int w2, int h2, char expand) {
    for(int i=0; i < 32; i++) {
        int x = (x1 * (32 - i) + x2 * i) >> 5;
        int y = (y1 * (32 - i) + y2 * i) >> 5;
        int w = (w1 * (32 - i) + w2 * i) >> 5;
        int h = (h1 * (32 - i) + h2 * i) >> 5;
        renderInvertOutline(x,y,w,h);
        if(expand)
            Eep(50000/(i+1));
        else
            Eep(50000/(32-i));
        renderInvertOutline(x,y,w,h);
    }
}

void* iconPack;
PSFHeader* unifont;

DockItem* dockHead = NULL;
DockItem* dockTail = NULL;
int dockItems = 0;

void RedrawDock() {
    if(dockWin.frontBuf != NULL) {
        free(dockWin.frontBuf);
    }
    dockWin.frontBuf = malloc(dockItems*(48*48*4));
    dockWin.w = 48*dockItems;
    dockWin.h = 48;
    dockWin.x = (fbInfo.width/2)-(dockWin.w/2);
    dockWin.y = fbInfo.height-48;
    GraphicsContext* gfx = Graphics_NewContext(dockWin.frontBuf,dockWin.w,dockWin.h);
    UIDrawRoundedBox(gfx,0,0,dockWin.w,dockWin.h+5,0x8018181b,0);
    int i = 0;
    DockItem* item = dockHead;
    while(item != NULL) {
        Graphics_RenderIcon(gfx,iconPack,item->icon,i+8,8,32,32,item->pressed ? 0xffa0a0a0 : 0xffffffff);
        i += 48;
        item = item->next;
    }
    free(gfx);
    Redraw(0,dockWin.y,fbInfo.width,dockWin.h);
}

void NewDockItem(const char* icon, const char* path) {
    DockItem* entry = malloc(sizeof(DockItem));
    entry->icon = icon;
    entry->path = path;
    entry->next = NULL;
    entry->pressed = 0;
    entry->prev = dockTail;
    if(dockTail != NULL) {
        dockTail->next = entry;
    }
    dockTail = entry;
    if(dockHead == NULL) {
        dockHead = entry;
    }
    dockItems += 1;
    RedrawDock();
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

int main(int argc, const char* argv[]) {
    msgQueue = MQueue_Bind("/dev/mqueue/Raven");
    iconPack = Graphics_LoadIconPack("/System/Icons/IconPack");
    unifont = Graphics_LoadFont("/System/Fonts/unifont.psf");
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
    NewDockItem("User/Administrator","/bin/hunter");
    NewDockItem("App/Settings","/bin/settings");
    NewDockItem("File/Archive","/bin/welcome");
    LoadBackground("/System/Wallpapers/Aurora.qoi");
    while(1) {
        int64_t teamID;
        RavenPacket* packet = MQueue_RecieveFromClient(msgQueue,&teamID,NULL);
        switch(packet->type) {
            case RAVEN_OKEE_BYEEEE: {
                SpinlockAcquire(&windowLock);
                Window* win = winTail;
                while(win != NULL) {
                    if(win->owner == teamID) {
                        if(win == winFocus) {
                            winFocus = NULL;
                        }
                        void* prev = win->prev;
                        int64_t creator = win->creator;
                        int x = win->x;
                        int y = win->y;
                        int w = win->w;
                        int h = win->h;
                        if(win->prev != NULL) {
                            ((Window*)win->prev)->next = win->next;
                        }
                        if(win->next != NULL) {
                            ((Window*)win->next)->prev = win->prev;
                        }
                        if(win == winTail) {
                            winTail = win->prev;
                        }
                        if(win == winHead) {
                            winHead = win->next;
                        }
                        free(win->frontBuf);
                        MUnMap(win->backBuf,(win->w*win->h)*4);
                        DestroySharedMemory(win->shmID);
                        free(win);
                        SpinlockRelease(&windowLock);
                        Redraw(x,y,w,h);
                        SpinlockAcquire(&windowLock);
                        win = prev;
                    } else {
                        win = win->prev;
                    }
                }
                SpinlockRelease(&windowLock);
                break;
            }
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
                win->creator = packet->create.creator;
                winTail = win;
                if(winHead == NULL) {
                    winHead = win;
                }
                RavenCreateWindowResponse response;
                response.id = win->id;
                response.backBuf = win->shmID;
                MQueue_SendToClient(msgQueue,teamID,&response,sizeof(RavenCreateWindowResponse));
                SpinlockRelease(&windowLock);
                if(packet->create.creator != 0) {
                    Window* cwin = GetWindowByID(packet->create.creator);
                    if(cwin != NULL) {
                        DoBoxAnimation(cwin->x,cwin->y,cwin->w,cwin->h,win->x,win->y,win->w,win->h,1);
                    }
                }
                Redraw(win->x,win->y,win->w,win->h);
                break;
            }
            case RAVEN_DESTROY_WINDOW: {
                SpinlockAcquire(&windowLock);
                Window* win = GetWindowByID(packet->move.id);
                if(win == winFocus) {
                    winFocus = NULL;
                }
                void* prev = win->prev;
                int64_t creator = win->creator;
                int x = win->x;
                int y = win->y;
                int w = win->w;
                int h = win->h;
                if(win->prev != NULL) {
                    ((Window*)win->prev)->next = win->next;
                }
                if(win->next != NULL) {
                    ((Window*)win->next)->prev = win->prev;
                }
                if(win == winTail) {
                    winTail = win->prev;
                }
                if(win == winHead) {
                    winHead = win->next;
                }
                free(win->frontBuf);
                MUnMap(win->backBuf,(win->w*win->h)*4);
                DestroySharedMemory(win->shmID);
                free(win);
                SpinlockRelease(&windowLock);
                Redraw(x,y,w,h);
                if(creator != 0) {
                    Window* cwin = GetWindowByID(creator);
                    if(cwin != NULL) {
                        DoBoxAnimation(x,y,w,h,cwin->x,cwin->y,cwin->w,cwin->h,0);
                    }
                }
                break;
            }
            case RAVEN_MOVE_WINDOW: {
                int oldX, oldY;
                SpinlockAcquire(&windowLock);
                Window* win = GetWindowByID(packet->move.id);
                oldX = win->x;
                oldY = win->y;
                win->x = packet->move.x;
                win->y = packet->move.y;
                SpinlockRelease(&windowLock);
                Redraw(oldX,oldY,win->w,win->h);
                Redraw(win->x,win->y,win->w,win->h);
                break;
            }
            case RAVEN_GET_RESOLUTION: {
                RavenGetResolutionResponse response;
                response.w = fbInfo.width;
                response.h = fbInfo.height;
                MQueue_SendToClient(msgQueue,teamID,&response,sizeof(RavenGetResolutionResponse));
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
            case RAVEN_SET_BACKGROUND: {
                const char* path = (const char*)(((uintptr_t)packet)+4);
                LoadBackground(path);
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