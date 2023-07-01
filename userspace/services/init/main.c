#include <Filesystem/Filesystem.h>
#include <System/Syscall.h>

int main() {
    DirEntry entry;
    int64_t fd = Open("/dev",O_RDONLY | O_DIRECTORY);
    if(fd < 0) {
        RyuLog("Failed to open /dev!\n");
    }
    RyuLog("Contents of /dev:\n");
    for(int i=0;;i++) {
        if(ReadDir(fd,i,(void*)&entry) == 0) {
            break;
        }
        RyuLog("    ");
        RyuLog((const char*)&entry.name);
        RyuLog("\n");
    }
    if(Close(fd) != 0) {
        RyuLog("Failed to close /dev!\n");
    }
    while(1) {}
}