#include <Compositor/Window.h>
#include <Graphics/Framebuffer.h>
#include <Graphics/PSF.h>
#include <Utilities/String.h>

#define MIN(__x, __y) ((__x) < (__y) ? (__x) : (__y))

#define MAX(__x, __y) ((__x) > (__y) ? (__x) : (__y))

Window rootWindow;
Window rWindow;
Window reWindow;
uint32_t rootWinData[482*322];

Window* windowHead;
Window* windowTail;

extern void* _binary____files_knxt_psf_start;

/* Redraws a section of the framebuffer. This allows compositor surfaces to be rendered */
void Compositor_WindowRedraw(int x, int y, int w, int h) {
    Window* win = windowHead;
    int max_x, max_y;
    max_x = x+(w-1);
    max_y = y+(h);
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

/* Returns a pointer to a window with the matching ID */
Window* Compositor_GetWindow(uint64_t id) {
  Window* win1 = windowHead; /* By searching both the head and the tail at the same time, 
                                we can increase the speed of searching through the list */
  Window* win2 = windowTail;
  while(win1 != 0 && win2 != 0) {
    if(win1->id == id) {
      return win1;
    } else if(win2->id == id) {
      return win2;
    }
    if(win1->next == win2 || win2->prev == win1) {
       break;
    }
    win1 = win1->next;
    if(win2->prev != win1) {
      win2 = win2->prev;
    }
  }
  return 0;
}

/* Moves the given window to the tail of the linked list
 * This makes the window render last, putting it to the front of the screen
 */
void Compositor_MoveWindowToFront(Window* win) {
  if(win == 0) {
    return;
  }
  if(windowTail == win) {
    return;
  }
  if(windowHead == win) {
    windowHead = win->next;
  }
  if(win->prev != 0) {
    ((Window*)(win->prev))->next = win->next;
  }
  if(win->next != 0) {
    ((Window*)(win->next))->prev = win->prev;
  }
  windowTail->next = win;
  win->prev = windowTail;
  win->next = 0;
  windowTail = win;
}

void Compositor_WindowSetup() {
    rootWindow.next = &rWindow;
    rootWindow.prev = 0;
    rootWindow.id = 1;
    rootWindow.x = (fbWidth/2)-(482/2);
    rootWindow.y = (fbHeight/2)-(322/2);
    rootWindow.w = 482;
    rootWindow.h = 322;
    rootWindow.backBuffer = (uint32_t*)&rootWinData;
    rootWindow.frontBuffer = (uint32_t*)&rootWinData;
    rWindow.next = &reWindow;
    rWindow.prev = &rootWindow;
    rWindow.id = 2;
    rWindow.x = 0;
    rWindow.y = 0;
    rWindow.w = 482;
    rWindow.h = 322;
    rWindow.backBuffer = (uint32_t*)&rootWinData;
    rWindow.frontBuffer = (uint32_t*)&rootWinData;
    reWindow.next = 0;
    reWindow.prev = &rWindow;
    reWindow.id = 3;
    reWindow.x = fbWidth-482;
    reWindow.y = 0;
    reWindow.w = 482;
    reWindow.h = 322;
    reWindow.backBuffer = (uint32_t*)&rootWinData;
    reWindow.frontBuffer = (uint32_t*)&rootWinData;
    windowHead = &rootWindow;
    windowTail = &reWindow;
    Framebuffer_SwapBuffer((uint8_t*)rootWindow.frontBuffer,rootWindow.w,rootWindow.h,32);
    Framebuffer_DrawRect(0,0,fbWidth,fbHeight,0xff505050);
    Framebuffer_DrawRect(1,1,fbWidth-2,fbHeight-3,0xff101010);
    Framebuffer_RenderString(1,1,0xff505050,(PSFHeader*)&_binary____files_knxt_psf_start,"System Console");
    Framebuffer_SwapBuffer(0,0,0,0);
    Compositor_WindowRedraw(0,0,fbWidth,fbHeight);
}