#include <Raven/Raven.h>
#include <Raven/UI.h>
#include <System/Syscall.h>
#include <Common/Alloc.h>
#include <Media/Graphics.h>
#include <System/Thread.h>
#include <Raven/Widgets/Button.h>
#include <Raven/Widgets/Image.h>
#include <Raven/Widgets/Label.h>
#include <Raven/Widgets/Badge.h>
#include <Raven/Widgets/TextArea.h>

int main(int argc, char* argv[]) {
    RavenSession* session = NewRavenSession();
    ClientWindow* win = NewRavenWindow(session,700,500,FLAG_ACRYLIC | FLAG_RESIZE,0);
    if(win == NULL) {
        RyuLog("Unable to open window!\n");
        return 0;
    }
    NewIconButtonWidget(win,DEST_TOOLBAR,0,0,16,16,"Action/About",NULL);
    NewTextAreaWidget(win,DEST_WIDGETS,1,65,698,500-64-32);
    UIAddWindow(session,win,"Scholar",NULL);
    UIRun(session);
}