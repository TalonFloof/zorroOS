#include <Compositor/Window.h>
#include <Graphics/Framebuffer.h>
#include <Utilities/String.h>

Window rootWindow;
uint32_t rootWinData[640*480];

Window* windowHead;
Window* windowTail;

void Compositor_WindowRedraw() {
    Window* win = windowHead;
    while(win != (Window*)0) {
        int i;
        for(i=0;i < win->h;i++) {
            memcpy(&(((uint32_t*)fbPtr)[((win->y+i)*fbWidth)+win->x]),&(win->data[i*win->w]),win->w*4);
        }
        win = win->next;
    }
}

void Compositor_WindowSetup() {
    rootWindow.next = 0;
    rootWindow.prev = 0;
    rootWindow.x = (fbWidth/2)-320;
    rootWindow.y = (fbHeight/2)-240;
    rootWindow.w = 640;
    rootWindow.h = 480;
    rootWindow.data = (uint32_t*)&rootWinData;
    windowHead = &rootWindow;
    windowTail = &rootWindow;
    Compositor_WindowRedraw();
}