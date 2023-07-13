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
#include <Media/QOI.h>
#include <Media/Image.h>

void ExitAbout(RavenSession* session, ClientWindow* win, int64_t id) {
    CloseRavenSession(session);
    Exit(0);
}

int main(int argc, char* argv[]) {
    RavenSession* session = NewRavenSession();
    ClientWindow* win = NewRavenWindow(session,560,360,0);
    if(win == NULL) {
        RyuLog("Unable to open window!\n");
        return 0;
    }
    qoi_desc aboutDesc;
    void* aboutImage = qoi_read("/System/Icons/zorroOS Stylized Banner.qoi",&aboutDesc,4);
    Image_ABGRToARGB((uint32_t*)aboutImage,aboutDesc.width*aboutDesc.height);
    NewImageWidget(win,DEST_WIDGETS,1,32,240,328,aboutImage);
    NewLabelWidget(win,DEST_WIDGETS,248,48,"zorroOS",LABEL_EXTRA_LARGE);
    NewBadgeWidget(win,DEST_WIDGETS,382,57,"Aurora",0);
    NewLabelWidget(win,DEST_WIDGETS,248,90,"Copyright (C) 2020-2023",LABEL_NORMAL);
    NewLabelWidget(win,DEST_WIDGETS,248,90+24,"TalonFox and contributers",LABEL_NORMAL);
    NewButtonWidget(win,DEST_WIDGETS,490,320,8,8,1,"Got it",NULL,&ExitAbout);
    UIRun(session,win,"About zorroOS",NULL);
}