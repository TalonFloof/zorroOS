#include "mouse.h"
#include <System/Thread.h>
#include <Filesystem/Filesystem.h>
#include <Common/Spinlock.h>
#include <Filesystem/MQueue.h>
#include "raven.h"
#include <stdbool.h>

bool lButton = false;
int winX = 0;
int winY = 0;
Window* winDrag = NULL;
Window* iconSelect = NULL;
Window* iconDrag = NULL;

void invertPixel(int x, int y) {
    if(x >= 0 && x < fbInfo.width && y >= 0 && y < fbInfo.height) {
        fbInfo.addr[(y*(fbInfo.pitch/(fbInfo.bpp/8)))+x] = ~fbInfo.addr[(y*(fbInfo.pitch/(fbInfo.bpp/8)))+x];
    }
}

void renderInvertOutline(int x, int y, int w, int h) {
    for(int i=x+5; i < x+(w-5); i++) {
        invertPixel(i,y);
        invertPixel(i,y+(h-1));
    }
    for(int i=y+5; i < y+(h-5); i++) {
        invertPixel(x,i);
        invertPixel(x+(w-1),i);
    }
    // Top Left
    invertPixel(x+3,y+1);
    invertPixel(x+4,y+1);
    invertPixel(x+2,y+2);
    invertPixel(x+1,y+3);
    invertPixel(x+1,y+4);
    // Top Right
    invertPixel((x+w)-5,y+1);
    invertPixel((x+w)-4,y+1);
    invertPixel((x+w)-3,y+2);
    invertPixel((x+w)-2,y+3);
    invertPixel((x+w)-2,y+4);
    // Bottom Left
    invertPixel(x+3,(y+h)-2);
    invertPixel(x+4,(y+h)-2);
    invertPixel(x+2,(y+h)-3);
    invertPixel(x+1,(y+h)-4);
    invertPixel(x+1,(y+h)-5);
    // Bottom Right
    invertPixel((x+w)-5,(y+h)-2);
    invertPixel((x+w)-4,(y+h)-2);
    invertPixel((x+w)-3,(y+h)-3);
    invertPixel((x+w)-2,(y+h)-4);
    invertPixel((x+w)-2,(y+h)-5);
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
                if(iconSelect != NULL && (buttons & 1) == 1) {
                    iconDrag = iconSelect;
                    iconSelect = NULL;
                    winX = cursorWin.x - iconDrag->x;
                    winY = cursorWin.y - iconDrag->y;
                    renderInvertOutline(cursorWin.x - winX, cursorWin.y - winY, 32, 32);
                } else if(iconDrag != NULL) {
                    Redraw(oldX - winX, oldY - winY, 32, 32);
                    renderInvertOutline(cursorWin.x - winX, cursorWin.y - winY, 32, 32);
                }
                if (winDrag != NULL) {
                    renderInvertOutline(oldX - winX, oldY - winY, winDrag->w, winDrag->h);
                    renderInvertOutline(cursorWin.x - winX, cursorWin.y - winY, winDrag->w, winDrag->h);
                }
            }
            if ((buttons & 1) == 0 && lButton) {
                if(iconDrag != NULL) {
                    int oldX = iconDrag->x;
                    int oldY = iconDrag->y;
                    iconDrag->x = cursorWin.x - winX;
                    iconDrag->y = cursorWin.y - winY;
                    Redraw(oldX,oldY,iconDrag->w,iconDrag->h);
                    Redraw(iconDrag->x,iconDrag->y,iconDrag->w,iconDrag->h);
                    iconSelect = iconDrag;
                    iconDrag = NULL;
                } else  if(winDrag != NULL) {
                    int oldX = winDrag->x;
                    int oldY = winDrag->y;
                    winDrag->x = cursorWin.x - winX;
                    winDrag->y = cursorWin.y - winY;
                    MoveWinToFront(winDrag);
                    if(oldX != winDrag->x || oldY != winDrag->y) {
                        Redraw(oldX,oldY,winDrag->w,winDrag->h);
                        Redraw(winDrag->x,winDrag->y,winDrag->w,winDrag->h);
                    } else {
                        renderInvertOutline(winDrag->x, winDrag->y, winDrag->w, winDrag->h);
                    }
                    winDrag = NULL;
                } else if (winFocus != NULL) {
                    if(cursorWin.x >= winFocus->x && cursorWin.x <= winFocus->x+winFocus->w && cursorWin.y >= winFocus->y && cursorWin.y <= winFocus->y+winFocus->h) {
                        RavenEvent event;
                        event.type = RAVEN_MOUSE_RELEASED;
                        event.mouse.x = cursorWin.x-winFocus->x;
                        event.mouse.y = cursorWin.y-winFocus->y;
                        event.mouse.buttons = 0;
                        MQueue_SendToClient(msgQueue,winFocus->owner,&event,sizeof(RavenEvent));
                    }
                }
            } else if ((buttons & 1) != 0 && !lButton) {
                SpinlockAcquire(&windowLock);
                Window* win = winTail;
                bool clicked = false;
                while(win != NULL) {
                    if(cursorWin.x >= win->x && cursorWin.x < win->x+win->w && cursorWin.y >= win->y && cursorWin.y < win->y+32 && !(win->flags & FLAG_NOMOVE)) {
                        winDrag = win;
                        winX = cursorWin.x - win->x;
                        winY = cursorWin.y - win->y;
                        renderInvertOutline(cursorWin.x - winX,cursorWin.y - winY,win->w,win->h);
                        clicked = true;
                        break;
                    } else if(cursorWin.x >= win->x && cursorWin.x <= win->x+win->w && cursorWin.y >= win->y && cursorWin.y <= win->y+win->h) {
                        // Mouse Click Event
                        if(win != winFocus) {
                            if(win != winTail) {
                                SpinlockRelease(&windowLock);
                                MoveWinToFront(win);
                                Redraw(win->x,win->y,win->w,win->h);
                                SpinlockAcquire(&windowLock);
                            }
                            winFocus = win;
                        } else {
                            RavenEvent event;
                            event.type = RAVEN_MOUSE_PRESSED;
                            event.mouse.x = cursorWin.x-win->x;
                            event.mouse.y = cursorWin.y-win->y;
                            event.mouse.buttons = 1;
                            MQueue_SendToClient(msgQueue,win->owner,&event,sizeof(RavenEvent));
                        }
                        clicked = true;
                        break;
                    }
                    win = win->prev;
                }
                if(!clicked) {
                    winFocus = NULL;
                }
                SpinlockRelease(&windowLock);
                if(!clicked) {
                    win = iconHead;
                    while(win != NULL) {
                        if(cursorWin.x >= win->x && cursorWin.x <= win->x+win->w && cursorWin.y >= win->y && cursorWin.y <= win->y+32) {
                            if(iconSelect != NULL) {
                                uint32_t* temp = iconSelect->frontBuf;
                                iconSelect->frontBuf = iconSelect->backBuf;
                                iconSelect->backBuf = temp;
                                Redraw(iconSelect->x,iconSelect->y,iconSelect->w,iconSelect->h);
                            }
                            uint32_t* temp = win->frontBuf;
                            win->frontBuf = win->backBuf;
                            win->backBuf = temp;
                            Redraw(win->x,win->y,win->w,win->h);
                            iconSelect = win;
                            clicked = true;
                            break;
                        }
                        win = win->next;
                    }
                }
                if(!clicked) {
                    if(iconSelect != NULL) {
                        uint32_t* temp = iconSelect->frontBuf;
                        iconSelect->frontBuf = iconSelect->backBuf;
                        iconSelect->backBuf = temp;
                        Redraw(iconSelect->x,iconSelect->y,iconSelect->w,iconSelect->h);
                    }
                    iconSelect = NULL;
                }
            }
            lButton = (buttons & 1) != 0;
        } else {
            RyuLog("WARNING: /dev/ps2mouse returned unusual value!\n");
        }
    }
}