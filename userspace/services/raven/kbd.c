#include "kbd.h"
#include <System/Thread.h>
#include <Filesystem/Filesystem.h>

void KeyboardThread() {
    OpenedFile kbdFile;
    if(Open("/dev/ps2kbd",O_RDONLY,&kbdFile) < 0) {
        RyuLog("Failed to open /dev/ps2kbd!\n");
        Exit(1);
    }
    char packet;
    while(1) {
        if(kbdFile.Read(&kbdFile,(void*)&packet,1) == 1) {
            
        } else {
            RyuLog("WARNING: /dev/ps2kbd returned unusual value!\n");
        }
    }
}