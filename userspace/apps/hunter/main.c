#include <Raven/Raven.h>
#include <Raven/UI.h>
#include <System/Syscall.h>
#include <Common/Alloc.h>
#include <Media/Graphics.h>
#include <Raven/Widgets/Label.h>
#include <Raven/Widgets/Button.h>
#include <System/Thread.h>

int main(int argc, const char* argv[]) {
    if(argc == 2) { // Set Current Directory to This
        ChDir(argv[1]);
    }
    RavenSession* session = NewRavenSession();
    ClientWindow* win = NewRavenWindow(session,560,360,FLAG_ACRYLIC);
    if(win == NULL) {
        RyuLog("Unable to open window!\n");
        return 0;
    }
    NewIconButtonWidget(win,DEST_TOOLBAR,0,0,16,13,"Action/Left",NULL);
    NewIconButtonWidget(win,DEST_TOOLBAR,0,0,16,13,"Action/Right",NULL);
    OpenedFile dir;
    DirEntry entry;
    if(argc == 2) {
        Open(argv[1],O_DIRECTORY | O_RDONLY,&dir);
    } else {
        Open("/",O_DIRECTORY | O_RDONLY,&dir);
    }
    int i = 0;
    while(dir.ReadDir(&dir,i,&entry)) {
        NewIconButtonWidget(win,DEST_WIDGETS,2+(64*i),65,32,32,entry.mode & 0040000 != 0 ? "File/Directory" : "File/Generic",NULL);
        i++;
    }
    dir.Close(&dir);
    UIRun(session,win,"Root",NULL);
}