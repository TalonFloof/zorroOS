#include <Raven/Raven.h>
#include <System/Syscall.h>
#include <Common/Alloc.h>
#include <Media/Graphics.h>

int main() {
    RavenSession* session = NewRavenSession();
    ClientWindow* win = NewRavenWindow(session,640,480,FLAG_ACRYLIC);
    if(win == NULL) {
        RyuLog("Unable to open window!\n");
        return 0;
    }
    GraphicsContext* gfx = Graphics_NewContext(win->backBuf,win->w,win->h);
    PSFHeader* knxt = Graphics_LoadFont("/System/Fonts/knxt.psf");
    PSFHeader* unifont = Graphics_LoadFont("/System/Fonts/unifont.psf");
    void* iconPack = Graphics_LoadIconPack("/System/Icons/IconPack");
    Graphics_DrawRect(gfx,0,0,640,192,0xa0000000);
    Graphics_DrawRect(gfx,0,192,640,480-192,0xff222222);
    Graphics_RenderIcon(gfx,iconPack,"File/Archive",640-192,480-192,256,256,0xff333333);
    for(int i=480-191; i < 480; i+=2) {
        Graphics_DrawRect(gfx,0,i,640,1,0xff222222);
    }
    RavenDrawWindowDecoration(win,gfx);
    Graphics_RenderCenteredString(gfx,320,192-(knxt->height*2),0xffffffff,knxt,2,"Welcome to zorroOS!");
    Graphics_RenderCenteredString(gfx,320,192+8,0xff555555,unifont,1,"zorroOS is a free hobby operating system created by TalonFox");
    Graphics_RenderCenteredString(gfx,320,192+24,0xff555555,unifont,1,"You are currently runnning off of a RamDisk");
    Graphics_RenderCenteredString(gfx,320,192+40,0xff555555,unifont,1,"You can install the OS or try it out if you want.");
    RavenFlipArea(session,win,0,0,640,480);
    while(1) {
        RavenEvent* event = RavenGetEvent(session);
        free(event);
    }
}