#include <System/Thread.h>
#include <System/Syscall.h>
#include <Filesystem/Filesystem.h>
#include "kbd.h"
#include "mouse.h"

typedef struct {
    uint32_t width;
    uint32_t height;
    uint32_t pitch;
    uint32_t bpp;
} FBInfo;

int main() {
    OpenedFile fbFile;
    FBInfo fbInfo;
    if(Open("/dev/fb0",O_RDWR,&fbFile) < 0) {
        RyuLog("Failed to open /dev/fb0!\n");
        return 1;
    }
    fbFile.IOCtl(&fbFile,0x100,&fbInfo);
    uint32_t* framebuffer = MMap(NULL,fbInfo.pitch*fbInfo.height,3,MAP_SHARED,fbFile.fd,0);
    fbFile.Close(&fbFile);
    //for(int i=0; i < fbInfo.width*fbInfo.height; i++) {
    //    framebuffer[i] = 0x303030;
    //}
    void* kbdStack = MMap(NULL,0x4000,3,MAP_ANONYMOUS,0,0);
    uintptr_t kbdThr = NewThread("Raven Keyboard Thread",&KeyboardThread,(void*)(((uintptr_t)kbdStack)+0x3ff8));
    void* mouseStack = MMap(NULL,0x4000,3,MAP_ANONYMOUS,0,0);
    uintptr_t mouseThr = NewThread("Raven Mouse Thread",&MouseThread,(void*)(((uintptr_t)mouseStack)+0x3ff8));
    while(1) {
    }
    return 0;
}