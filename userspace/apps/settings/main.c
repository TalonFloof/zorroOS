#include <Raven/UI.h>
#include <Raven/Raven.h>
#include <Raven/Widgets/Button.h>
#include <Raven/Widgets/Label.h>
#include <Filesystem/Filesystem.h>
#include <Media/QOI.h>
#include <Media/Image.h>
#include <Common/Alloc.h>
#include <Common/String.h>

void BackToMain(RavenSession* session, ClientWindow* win, uint64_t id);

typedef struct { // 128x72
    void* next;
    uint32_t image[128*72];
    char path[];
} BackgroundPreview;

BackgroundPreview* backgrounds = NULL;

void Backgrounds(RavenSession* session, ClientWindow* win, uint64_t id) {
    UIRemoveWidgets(win);
    NewIconButtonWidget(win,DEST_TOOLBAR,0,0,16,13,"Action/Left",&BackToMain);
    UIDrawBaseWindow(session,win,win->gfx,"Backgrounds",NULL);
    RavenFlipArea(session,win,0,0,win->w,win->h);
    if(backgrounds == NULL) {
        // Get the list of backgrounds
        OpenedFile dir;
        DirEntry entry;
        Open("/System/Wallpapers/",O_RDONLY | O_DIRECTORY,&dir);
        int i = 0;
        while(dir.ReadDir(&dir,i,&entry) > 0) {
            BackgroundPreview* bgEntry = malloc(sizeof(BackgroundPreview)+19+entry.nameLen+1);
            memcpy(bgEntry->path,"/System/Wallpapers/",19);
            memcpy(bgEntry->path+19,&entry.name,entry.nameLen+1);
            qoi_desc desc;
            uint32_t* data = (uint32_t*)qoi_read((const char*)bgEntry->path,&desc,4);
            Image_ScaleNearest(data,(uint32_t*)&bgEntry->image,desc.width,desc.height,128,72);
            free(data);
            Image_ABGRToARGB((uint32_t*)&bgEntry->image,128*72);
            bgEntry->next = backgrounds;
            backgrounds = bgEntry;
            i++;
        }
        dir.Close(&dir);
    }
}

void MainScreenDisplay(ClientWindow* win) {
    UIRemoveWidgets(win);
    NewLabelWidget(win,DEST_WIDGETS,2,32,"General",LABEL_LARGE);
    NewButtonWidget(win,DEST_WIDGETS,2,32+21,0,0,2,"Backgrounds","App/Settings",&Backgrounds);
}

void BackToMain(RavenSession* session, ClientWindow* win, uint64_t id) {
    MainScreenDisplay(win);
    UIDrawBaseWindow(session,win,win->gfx,"Settings","App/Settings");
    RavenFlipArea(session,win,0,0,win->w,win->h);
}

int main(int argc, char* argv[]) {
    RavenSession* session = NewRavenSession();
    ClientWindow* mainWin = NewRavenWindow(session,640,480,FLAG_ACRYLIC,0);
    MainScreenDisplay(mainWin);
    UIAddWindow(session,mainWin,"Settings","App/Settings");
    UIRun(session);
}