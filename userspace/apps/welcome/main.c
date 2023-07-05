#include <Raven/Raven.h>

int main() {
    RavenSession* session = NewRavenSession();
    ClientWindow* win = NewRavenWindow(session,640,480,FLAG_ACRYLIC);
    if(win == NULL) {
        RyuLog("Unable to open window!\n");
        return 0;
    }
    for(int i=0; i < 640*480; i++) {
        win->backBuf[i] = 0xa0333333;
    }
    RavenFlipArea(session,win,0,0,640,480);
    ClientWindow* win2 = NewRavenWindow(session,256,256,FLAG_OPAQUE);
    while(1) {
        
    }
}