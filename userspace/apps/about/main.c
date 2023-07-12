#include <Raven/Raven.h>
#include <Raven/UI.h>
#include <System/Syscall.h>
#include <Common/Alloc.h>
#include <Media/Graphics.h>
#include <System/Thread.h>
#include <Raven/Widgets/Button.h>
#include <Raven/Widgets/Image.h>
#include <Media/QOI.h>
#include <Media/Image.h>

int main(int argc, char* argv[]) {
    RavenSession* session = NewRavenSession();
    ClientWindow* win = NewRavenWindow(session,560,360,0);
    if(win == NULL) {
        RyuLog("Unable to open window!\n");
        return 0;
    }
    qoi_desc aboutDesc;
    void* tempImage = qoi_read("/System/Icons/zorroOS Stylized Banner.qoi",&aboutDesc,4);
    Image_ABGRToARGB((uint32_t*)tempImage,aboutDesc.width*aboutDesc.height);
    void* aboutImage = malloc(150*328*4);
    Image_ScaleNearest((uint32_t*)tempImage,aboutImage,aboutDesc.width,aboutDesc.height,150,328);
    free(tempImage);
    NewImageWidget(win,1,32,150,328,aboutImage);
    UIRun(session,win,"About zorroOS",NULL);
}