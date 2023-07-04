#include "mouse.h"
#include <System/Thread.h>
#include <Filesystem/Filesystem.h>
#include "raven.h"

void MouseThread() {
    OpenedFile mouseFile;
    unsigned char packet[3] = {0,0,0};
    if(Open("/dev/ps2mouse",O_RDONLY,&mouseFile) < 0) {
        RyuLog("Failed to open /dev/ps2mouse!\n");
        Exit(1);
    }
    while(1) {
        if(mouseFile.Read(&mouseFile,(void*)&packet,3) == 3) {
            int relX = ((int)((unsigned int)packet[1])) - ((int)((((unsigned int)packet[0]) << 4) & 0x100));
            int relY = 0 - (((int)((unsigned int)packet[2])) - ((int)((((unsigned int)packet[0]) << 3) & 0x100)));
            if (relX != 0 || relY != 0) {
                int oldX = cursorWin.x;
                int oldY = cursorWin.y;
                cursorWin.x += relX;
                cursorWin.y += relY;
                if(cursorWin.x < 0) {
                    cursorWin.x = 0;
                } else if(cursorWin.x >= fbInfo.width) {
                    cursorWin.x = fbInfo.width - 1;
                }
                if(cursorWin.y < 0) {
                    cursorWin.y = 0;
                } else if(cursorWin.y >= fbInfo.height) {
                    cursorWin.y = fbInfo.height - 1;
                }
                Redraw(oldX,oldY,cursorWin.w,cursorWin.h);
                Redraw(cursorWin.x,cursorWin.y,cursorWin.w,cursorWin.h);
            }
        } else {
            RyuLog("WARNING: /dev/ps2mouse returned unusual value!\n");
        }
    }
}