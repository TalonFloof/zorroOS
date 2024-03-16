#include <Raven/UI.h>
#include <Raven/Raven.h>
#include <Raven/Widgets/Button.h>
#include <Raven/Widgets/Label.h>
#include <Filesystem/Filesystem.h>
#include <Media/QOI.h>
#include <Media/Image.h>
#include <Common/Alloc.h>
#include <Common/String.h>

void BackToMain(RavenSession* session, ClientWindow* win, void* button);

typedef struct { // 128x72
    void* next;
    uint32_t image[128*72];
    char path[];
} BackgroundPreview;

BackgroundPreview* backgrounds = NULL;

static void DrawImage(GraphicsContext* gfx, int x, int y, int w, int h, uint32_t* data) {
    for(int i=0; i < h; i++) {
        memcpy(&gfx->buf[((y+i)*gfx->w)+x],&data[i*w],w*4);
    }
}

static void BackgroundPickerRedraw(void* self, RavenSession* session, ClientWindow* win, GraphicsContext* gfx) {
    UIWidget* widget = (UIWidget*)self;
    BackgroundPreview* bg = backgrounds;
    int i = 0;
    while(bg != NULL) {
        int x = ((i % 4) * 160) + 16;
        int y = ((i / 4) * 132) + 30;
        DrawImage(gfx,x,widget->y+y,128,72,(uint32_t*)&bg->image);
        bg = bg->next;
        i += 1;
    }
}

static void BackgroundPickerEvent(void* self, RavenSession* session, ClientWindow* win, GraphicsContext* gfx, RavenEvent* event) {
    UIWidget* widget = (UIWidget*)self;
    if(event->type == RAVEN_MOUSE_PRESSED) {
        BackgroundPreview* bg = backgrounds;
        int i = 0;
        while(bg != NULL) {
            int x = ((i % 4) * 160);
            int y = ((i / 4) * 132);
            if(event->mouse.x >= x && event->mouse.x < x+160 && event->mouse.y >= y+widget->y && event->mouse.y < (y+widget->y)+132) {
                uint8_t* packet = malloc(5+strlen(bg->path));
                *((RavenPacketType*)packet) = RAVEN_SET_BACKGROUND;
                memcpy(&packet[4],bg->path,strlen(bg->path)+1);
                MQueue_SendToServer(session->raven,packet,5+strlen(bg->path));
                free(packet);
                break;
            }
            bg = bg->next;
            i += 1;
        }
    }
}

UIWidget* CreateBackgroundPicker() {
    UIWidget* widget = malloc(sizeof(UIWidget));
    widget->prev = NULL;
    widget->next = NULL;
    widget->privateData = NULL;
    widget->x = 1;
    widget->y = 64+20;
    widget->w = 640-2;
    widget->h = (480-64)-20;
    widget->Redraw = &BackgroundPickerRedraw;
    widget->Event = &BackgroundPickerEvent;
    return widget;
}

void Backgrounds(RavenSession* session, ClientWindow* win, void* button) {
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
            if(data == NULL) {
                RyuLog("Failed to load wallpaper!\n");
            }
            Image_ScaleNearest(data,(uint32_t*)&bgEntry->image,desc.width,desc.height,128,72);
            free(data);
            Image_ABGRToARGB((uint32_t*)&bgEntry->image,128*72);
            bgEntry->next = backgrounds;
            backgrounds = bgEntry;
            i++;
        }
        dir.Close(&dir);
    }
    UIRemoveWidgets(win);
    NewIconButtonWidget(win,DEST_TOOLBAR,0,0,16,13,"Action/Left",&BackToMain);
    UIAddWidget(win,CreateBackgroundPicker(),DEST_WIDGETS);
    UIDrawBaseWindow(session,win,win->gfx,"Backgrounds",NULL);
    RavenFlipArea(session,win,0,0,win->w,win->h);
}

void MainScreenDisplay(ClientWindow* win) {
    UIRemoveWidgets(win);
    NewLabelWidget(win,DEST_WIDGETS,2,32,"General",LABEL_LARGE);
    NewButtonWidget(win,DEST_WIDGETS,2,32+21,0,0,2,"Backgrounds","App/Settings",&Backgrounds);
    NewLabelWidget(win,DEST_WIDGETS,2,32+21+52,"Administration",LABEL_LARGE);
    NewButtonWidget(win,DEST_WIDGETS,2,32+21+21+52,0,0,2,"Users and Groups","User/Group",&Backgrounds);
}

void BackToMain(RavenSession* session, ClientWindow* win, void* button) {
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