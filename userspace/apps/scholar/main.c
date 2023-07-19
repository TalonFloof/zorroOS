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

RavenSession* session;
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

static void Load(char* path) {
    OpenedFile file;
    if(Open((const char*)path,O_RDONLY,&file) < 0) {
        return;
    }
    UIWidget* widget = UIGetWidget(win,textArea);
    UITextAreaPrivateData* txtArea = (UITextAreaPrivateData*)widget->privateData;
    for(int i=0; i < txtArea->lineCount; i++) {
        free(txtArea->lines[i]);
    }
    txtArea->lines = realloc(txtArea->lines,sizeof(void*));
    txtArea->lineCount = 0;
    txtArea->lines[0] = NULL;
    txtArea->cursorX = 0;
    txtArea->cursorY = 0;
    txtArea->scrollX = 0;
    txtArea->scrollY = 0;
    off_t size = file.LSeek(&file,0,SEEK_END);
    file.LSeek(&file,0,SEEK_SET);
    char* data = malloc(size+1);
    memset(data,0,size+1);
    file.Read(&file,data,size);
    file.Close(&file);
    for(int i=0; i <= size;) {
        int lineSize = 0;
        for(;data[i+lineSize] != 0 && data[i+lineSize] != '\n';lineSize++);
        txtArea->lines = realloc(txtArea->lines,sizeof(void*)*(txtArea->lineCount+1));
        txtArea->lines[txtArea->lineCount] = malloc(lineSize+1);
        txtArea->lines[txtArea->lineCount][lineSize] = 0;
        memcpy(txtArea->lines[txtArea->lineCount],data+i,lineSize);
        txtArea->lineCount++;
        i += lineSize+1;
    }
    free(data);
    UIRedrawWidgets(session,win,win->gfx);
}

static void SaveDialog(RavenSession* session, ClientWindow* win, void* button) {
    UISave(session,win,"File/Generic","TextFile",&Save);
}

int main(int argc, char* argv[]) {
    session = NewRavenSession();
    win = NewRavenWindow(session,700,500,FLAG_ACRYLIC | FLAG_RESIZE,0);
    if(win == NULL) {
        RyuLog("Unable to open window!\n");
        return 0;
    }
    NewIconButtonWidget(win,DEST_TOOLBAR,0,0,16,16,"Action/About",&SaveDialog);
    textArea = NewTextAreaWidget(win,DEST_WIDGETS,1,65,698,((500-64-16)/16)*16);
    UIRunOnLoad(&Load);
    UIAddWindow(session,win,"Scholar",NULL);
    UIRun(session);
}