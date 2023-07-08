#include <Raven/Raven.h>
#include <Raven/UI.h>
#include <System/Syscall.h>
#include <Common/Alloc.h>
#include <Media/Graphics.h>
#include <Raven/Widgets/Button.h>

int main() {
    RavenSession* session = NewRavenSession();
    ClientWindow* win = NewRavenWindow(session,640,480,FLAG_ACRYLIC);
    if(win == NULL) {
        RyuLog("Unable to open window!\n");
        return 0;
    }
    NewButtonWidget(win,50,50,0,0,"Install","File/Archive",NULL);
    UIRun(session,win);
}