#include <System/Thread.h>
#include <System/Syscall.h>
#include <Filesystem/Filesystem.h>

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
    uint32_t* framebuffer = MMap(NULL,fbInfo.pitch*fbInfo.height,3,0,fbFile.fd,0);
    fbFile.Close(&fbFile);
    for(int i=0; i < fbInfo.width*fbInfo.height; i++) {
        framebuffer[i] = 0x303030;
    }
    while(1) {
        Yield();
    }
    return 0;
}