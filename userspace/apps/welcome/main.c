#include <Raven/Raven.h>
#include <Raven/UI.h>
#include <System/Syscall.h>
#include <Common/Alloc.h>
#include <Media/Graphics.h>
#include <System/Thread.h>
#include <Raven/Widgets/Label.h>
#include <Raven/Widgets/Button.h>

void TryZorroOS(RavenSession* session, ClientWindow* win, void* button) {
    CloseRavenSession(session);
    Exit(0);
}

int main() {
    RavenSession* session = NewRavenSession();
    ClientWindow* win = NewRavenWindow(session,640,480,FLAG_ACRYLIC,0);
    if(win == NULL) {
        RyuLog("Unable to open window!\n");
        return 0;
    }
    NewButtonWidget(win,DEST_WIDGETS,(320-64),480-149,16,50,0,"Try","Device/CD",&TryZorroOS);
    NewButtonWidget(win,DEST_WIDGETS,(320-64)+64,480-149,0,50,0,"Install","File/Archive",NULL);
    NewLabelWidget(win,DEST_WIDGETS,64,64,"Welcome to zorroOS",LABEL_MORE_LARGE);
    UIAddWindow(session,win,"zorroOS Installer","File/Archive");
    UIRun(session);
}
