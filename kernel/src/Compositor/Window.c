#include <Compositor/Window.h>
#include <Graphics/Framebuffer.h>
#include <Graphics/PSF.h>
#include <Utilities/String.h>

#define MIN(__x, __y) ((__x) < (__y) ? (__x) : (__y))

#define MAX(__x, __y) ((__x) > (__y) ? (__x) : (__y))

Window rootWindow;
uint32_t rootWinData[482*322];

Window* windowHead;
Window* windowTail;

extern void* _binary____files_knxt_psf_start;

void Compositor_WindowRedraw(int x, int y, int w, int h) {
    Window* win = windowHead;
    int max_x, max_y;
    max_x = x+(w-1);
    max_y = y+(h-1);
    Framebuffer_DrawRect(x,y,w,h,0x392442);
    while(win != 0) {
        if(!(max_x <= win->x || max_y <= win->y || x >= (win->x+(win->w-1)) || y >= (win->y+(win->h-1)))) {
          int i;
          int fX1, fX2, fY1, fY2;
          fX1 = MAX(x,win->x);
          fX2 = MIN(max_x,win->x+(win->w-1));
          fY1 = MAX(y,win->y);
          fY2 = MIN(max_y,win->y+(win->h-1));
          for(i=fY1;i < fY2;i++) {
            memcpy(&(((uint32_t*)fbPtr)[(i*fbWidth)+fX1]),&(win->frontBuffer[((i-win->y)*win->w)+(fX1-win->x)]),((fX2-fX1)+1)*4);
          }
        }
        win = win->next;
    }
}

void Compositor_WindowSetup() {
    rootWindow.next = 0;
    rootWindow.prev = 0;
    rootWindow.x = (fbWidth/2)-(482/2);
    rootWindow.y = (fbHeight/2)-(322/2);
    rootWindow.w = 482;
    rootWindow.h = 322;
    rootWindow.backBuffer = (uint32_t*)&rootWinData;
    rootWindow.frontBuffer = (uint32_t*)&rootWinData;
    windowHead = &rootWindow;
    windowTail = &rootWindow;
    Framebuffer_SwapBuffer((uint8_t*)rootWindow.frontBuffer,rootWindow.w,rootWindow.h,32);
    Framebuffer_DrawRect(0,0,fbWidth,fbHeight,0x505050);
    Framebuffer_DrawRect(1,1,fbWidth-2,fbHeight-3,0x101010);
    Framebuffer_RenderString(1,1,0x505050,(PSFHeader*)&_binary____files_knxt_psf_start,"System Console");
    Framebuffer_SwapBuffer(0,0,0,0);
    Compositor_WindowRedraw(0,0,fbWidth,fbHeight);
}