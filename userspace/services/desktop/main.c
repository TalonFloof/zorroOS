#include <Raven/Raven.h>
#include <System/Syscall.h>
#include <Common/Alloc.h>
#include <Media/Graphics.h>
#include <Common/Time.h>
#include <System/Thread.h>

RavenSession* session;
ClientWindow* win;
GraphicsContext* gfx;
PSFHeader* knxt;

void ClockThread() {
    while(1) {
        Graphics_DrawRect(gfx,(win->w/2)-(4*knxt->width),0,8*knxt->width,32,0);
        UNIXTimestamp utime = GetTime();
        FormattedTime time = GetFormattedTime(utime);
        char buf[9] = {'0'+(time.hour/10),'0'+(time.hour%10),':','0'+(time.min/10),'0'+(time.min%10),':','0'+(time.sec/10),'0'+(time.sec%10),0};
        Graphics_RenderString(gfx,(win->w/2)-(4*knxt->width),16-(knxt->height/2),0xffffffff,knxt,1,(const char*)&buf);
        RavenFlipArea(session,win,(win->w/2)-(4*knxt->width),0,8*knxt->width,32);
        Eep((1000*1000) - (utime.nsecs / 1000));
    }
}

int main() {
    session = NewRavenSession();
    int w, h;
    RavenGetResolution(session,&w,&h);
    win = NewRavenWindow(session,w,32,FLAG_NOMOVE);
    RavenMoveWindow(session,win,0,0);
    gfx = Graphics_NewContext(win->backBuf,win->w,win->h);
    knxt = Graphics_LoadFont("/System/Fonts/knxt.psf");
    Graphics_RenderString(gfx,4,16-(knxt->height/2),0xffffffff,knxt,1,"zorroOS");
    RavenFlipArea(session,win,0,0,win->w,win->h);
    void* clockStack = MMap(NULL,0x8000,3,MAP_PRIVATE|MAP_ANONYMOUS,-1,0);
    ThreadID clockThr = NewThread("Desktop Clock Redraw Thread",&ClockThread,(void*)(((uintptr_t)clockStack) + 0x8000));
    while(1) {
        free(RavenGetEvent(session));
    }
}