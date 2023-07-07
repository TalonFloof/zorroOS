#include <Raven/Raven.h>
#include <System/Syscall.h>
#include <Common/Alloc.h>
#include <Media/Graphics.h>

int main() {
    RavenSession* session = NewRavenSession();
    int w, h;
    RavenGetResolution(session,&w,&h);
    ClientWindow* win = NewRavenWindow(session,w,32,FLAG_NOMOVE);
    RavenMoveWindow(session,win,0,0);
    GraphicsContext* gfx = Graphics_NewContext(win->backBuf,win->w,win->h);
    PSFHeader* knxt = Graphics_LoadFont("/System/Fonts/knxt.psf");
    Graphics_RenderString(gfx,4,16-(knxt->height/2),0xffffffff,knxt,1,"zorroOS");
    RavenFlipArea(session,win,0,0,win->w,win->h);
    while(1) {
        free(RavenGetEvent(session));
    }
}