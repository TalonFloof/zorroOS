#include "mouse.h"
#include <System/Thread.h>
#include <Filesystem/Filesystem.h>
#include "raven.h"
#include <stdbool.h>

bool lButton = false;
int winX = 0;
int winY = 0;
Window* winDrag = NULL;

void invertPixel(int x, int y) {
    if(x >= 0 && x < fbInfo.width && y >= 0 && fbInfo.height) {
        fbInfo.addr[(y*(fbInfo.pitch/(fbInfo.bpp/8)))+x] = ~fbInfo.addr[(y*(fbInfo.pitch/(fbInfo.bpp/8)))+x];
    }
}

void renderInvertOutline(int x, int y, int w, int h) {
    for(int i=0; i < w; i++) {
        if(i == 0 || i == w - 1) {
            for(int j=0; j < h; j++) {
                invertPixel(x + i, y + j);
            }
        } else {
            invertPixel(x + i, y);
            invertPixel(x + i, y + (h - 1));
        }
    }
}

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
            int buttons = packet[0] & 7;
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
                if (winDrag != NULL) {
                    renderInvertOutline(oldX - winX, oldY - winY, winDrag->w, winDrag->h);
                    renderInvertOutline(cursorWin.x - winX, cursorWin.y - winY, winDrag->w, winDrag->h);
                }
            }
            if ((buttons & 1) == 0 && lButton && winDrag != NULL) {
                int oldX = winDrag->x;
                int oldY = winDrag->y;
                winDrag->x = cursorWin.x - winX;
                winDrag->y = cursorWin.y - winY;
                Redraw(oldX,oldY,winDrag->w,winDrag->h);
                Redraw(winDrag->x,winDrag->y,winDrag->w,winDrag->h);
                winDrag = NULL;
            } else if ((buttons & 1) != 0 && !lButton) {
                Window* win = winTail;
                while(win != NULL) {
                    if(cursorWin.x >= win->x && cursorWin.x < win->x+win->w && cursorWin.y >= win->y && cursorWin.y < win->y+20 && !(win->flags & FLAG_NOMOVE)) {
                        winDrag = win;
                        winX = cursorWin.x - win->x;
                        winY = cursorWin.y - win->y;
                        renderInvertOutline(cursorWin.x - winX,cursorWin.y - winY,win->w,win->h);
                        break;
                    } else if(cursorWin.x >= win->x && cursorWin.x <= win->x+win->w && cursorWin.y >= win->y && cursorWin.y <= win->y+win->h) {
                        // Mouse Click Event
                        break;
                    }
                    win = win->prev;
                }
            }
            lButton = (buttons & 1) != 0;
        } else {
            RyuLog("WARNING: /dev/ps2mouse returned unusual value!\n");
        }
    }
}