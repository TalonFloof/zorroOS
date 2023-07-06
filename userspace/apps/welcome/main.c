#include <Raven/Raven.h>
#include <Raven/UI.h>
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
    UIRun(session,win);
}