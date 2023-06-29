#include <Filesystem/Filesystem.h>
#include <System/Syscall.h>

int main() {
    DirEntry entry;
    int64_t fd = Open("/",O_RDONLY | O_DIRECTORY);
    if(fd < 0) {
        RyuLog("Failed to open /!\n");
    }
    RyuLog("Contents of /:\n");
    for(int i=0;;i++) {
        if(ReadDir(fd,i,(void*)&entry) == 0) {
            break;
        }
        RyuLog("    ");
        RyuLog((const char*)&entry.name);
        RyuLog("\n");
    }
    if(Close(fd) != 0) {
        RyuLog("Failed to close /!\n");
    }
    while(1) {}
}