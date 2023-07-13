#include <Raven/Raven.h>
#include <Raven/UI.h>
#include <System/Syscall.h>
#include <Common/Alloc.h>
#include <Common/String.h>
#include <Media/Graphics.h>
#include <Raven/Widgets/Label.h>
#include <Raven/Widgets/Button.h>
#include <System/Thread.h>
#include <System/Team.h>

typedef struct {
    OpenedFile dir;
    char path[];
} FileBrowserPrivate;

extern void* RavenIconPack;
extern void* RavenTerminus;

UIWidget* CreateFileBrowser(const char* path);

static void FileBrowserRedraw(void* self, RavenSession* session, ClientWindow* win, GraphicsContext* gfx) {
    UIWidget* widget = (UIWidget*)self;
    FileBrowserPrivate* private = (FileBrowserPrivate*)widget->privateData;
    int i = 0;
    DirEntry entry;
    while(private->dir.ReadDir(&private->dir,i,&entry)) {
        int x = (560 / 8)*(i % 8);
        int y = 65+(48*(i/8));
        Graphics_RenderIcon(gfx,RavenIconPack,((entry.mode & 0770000) == 0040000) ? "File/Directory" : (((entry.mode & 07) == 07) ? "Object/Object" : "File/Generic"),x+(((560/8)/2)-16),y,32,32,0xffbcd7e8);
        Graphics_RenderCenteredString(gfx,x+((560/8)/2),y+32,0xffbcd7e8,RavenTerminus,1,(char *)&entry.name);
        i++;
    }
}

static void FileBrowserEvent(void* self, RavenSession* session, ClientWindow* win, GraphicsContext* gfx, RavenEvent* event) {
    UIWidget* widget = (UIWidget*)self;
    FileBrowserPrivate* private = (FileBrowserPrivate*)widget->privateData;
    if(event->type == RAVEN_MOUSE_PRESSED) {
        int i = 0;
        DirEntry entry;
        while(private->dir.ReadDir(&private->dir,i,&entry)) {
            int x = (560 / 8)*(i % 8);
            int y = 65+(48*(i/8));
            if(event->mouse.x >= x && event->mouse.x <= x+(560 / 8) && event->mouse.y >= y && event->mouse.y <= y+48) {
                if((entry.mode & 0770000) == 0040000) {
                    ClientWindow* w = NewRavenWindow(session,560,360,FLAG_ACRYLIC,win->id);
                    NewIconButtonWidget(w,DEST_TOOLBAR,0,0,16,13,"Action/Left",NULL);
                    NewIconButtonWidget(w,DEST_TOOLBAR,0,0,16,13,"Action/Right",NULL);
                    int len = strlen((const char*)private->path);
                    int fullLen = len+strlen((const char*)&entry.name);
                    char* path = malloc(fullLen+2);
                    memcpy(path,(const char*)private->path,len);
                    memcpy(path+len,(const char*)&entry.name,entry.nameLen);
                    path[fullLen] = '/';
                    path[fullLen+1] = 0;
                    UIAddWidget(w,CreateFileBrowser(path),DEST_WIDGETS);
                    free(path);
                    UIAddWindow(session,w,(const char*)&entry.name,NULL);
                } else if((entry.mode & 07) == 07) {
                    int len = strlen((const char*)private->path);
                    int fullLen = len+strlen((const char*)&entry.name);
                    char* path = malloc(fullLen+1);
                    memcpy(path,(const char*)private->path,len);
                    memcpy(path+len,(const char*)&entry.name,entry.nameLen+1);
                    TeamID team = NewTeam((const char*)&entry.name);
                    const char* args[] = {path,NULL};
                    LoadExecImage(team,args,NULL);
                    free(path);
                }
                break;
            }
            i++;
        }
    }
}

UIWidget* CreateFileBrowser(const char* path) {
    UIWidget* widget = malloc(sizeof(UIWidget));
    FileBrowserPrivate* private = malloc(sizeof(FileBrowserPrivate)+strlen(path)+1);
    Open(path,O_RDONLY | O_DIRECTORY,&private->dir);
    memcpy(private->path,path,strlen(path)+1);
    widget->privateData = private;
    widget->x = 1;
    widget->y = 64;
    widget->w = 560-2;
    widget->h = 360-64;
    widget->Redraw = &FileBrowserRedraw;
    widget->Event = &FileBrowserEvent;
    return widget;
}

int main(int argc, const char* argv[]) {
    RavenSession* session = NewRavenSession();
    ClientWindow* win = NewRavenWindow(session,560,360,FLAG_ACRYLIC,0);
    if(win == NULL) {
        RyuLog("Unable to open window!\n");
        return 0;
    }
    NewIconButtonWidget(win,DEST_TOOLBAR,0,0,16,13,"Action/Left",NULL);
    NewIconButtonWidget(win,DEST_TOOLBAR,0,0,16,13,"Action/Right",NULL);
    UIAddWidget(win,CreateFileBrowser(argc == 2 ? argv[1] : "/"),DEST_WIDGETS);
    UIAddWindow(session,win,"Root",NULL);
    UIRun(session);
}