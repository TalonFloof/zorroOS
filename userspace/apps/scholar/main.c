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
#include <Common/String.h>

ClientWindow* win;
int64_t textArea;

static void Save(char* path) {
    OpenedFile file;
    if(Open((const char*)path,O_RDWR,&file) < 0) {
        Create(path,0755);
        Open((const char*)path,O_RDWR,&file);
    } else {
        file.Truncate(&file,0);
    }
    UIWidget* widget = UIGetWidget(win,textArea);
    UITextAreaPrivateData* txtArea = (UITextAreaPrivateData*)widget->privateData;
    for(int i=0; i < txtArea->lineCount; i++) {
        char* line = txtArea->lines[i];
        file.Write(&file,line,strlen(line));
        if(i+1 < txtArea->lineCount) {
            file.Write(&file,"\n",1);
        }
    }
    file.Close(&file);
}

static void SaveDialog(RavenSession* session, ClientWindow* win, void* button) {
    UISave(session,win,"File/Generic","TextFile",&Save);
}

int main(int argc, char* argv[]) {
    RavenSession* session = NewRavenSession();
    win = NewRavenWindow(session,700,500,FLAG_ACRYLIC | FLAG_RESIZE,0);
    if(win == NULL) {
        RyuLog("Unable to open window!\n");
        return 0;
    }
    NewIconButtonWidget(win,DEST_TOOLBAR,0,0,16,16,"Action/About",&SaveDialog);
    textArea = NewTextAreaWidget(win,DEST_WIDGETS,1,65,698,((500-64-16)/16)*16);
    UIAddWindow(session,win,"Scholar",NULL);
    UIRun(session);
}