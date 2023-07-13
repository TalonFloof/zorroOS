#include "mouse.h"
#include <System/Thread.h>
#include <Filesystem/Filesystem.h>
#include <Common/Spinlock.h>
#include <Filesystem/MQueue.h>
#include <System/Team.h>
#include <Common/Alloc.h>
#include "raven.h"
#include <stdbool.h>

bool lButton = false;
int winX = 0;
int winY = 0;
Window* winDrag = NULL;
Window* iconSelect = NULL;
Window* iconDrag = NULL;

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
                    if(cursorWin.x >= iconSelect->x && cursorWin.x <= iconSelect->x+iconSelect->w && cursorWin.y >= iconSelect->y && cursorWin.y <= iconSelect->y+iconSelect->h) {
                        iconDrag = iconSelect;
                        iconSelect = NULL;
                        winX = cursorWin.x - iconDrag->x;
                        winY = cursorWin.y - iconDrag->y;
                        renderInvertOutline(cursorWin.x - winX, cursorWin.y - winY, 32, 32);
                    }
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
                    uint32_t* temp = iconDrag->frontBuf;
                    iconDrag->frontBuf = iconDrag->backBuf;
                    iconDrag->backBuf = temp;
                    Redraw(oldX,oldY,iconDrag->w,iconDrag->h);
                    Redraw(iconDrag->x,iconDrag->y,iconDrag->w,iconDrag->h);
                    iconSelect = NULL;
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
                    if(cursorWin.x >= win->x+32 && cursorWin.x < win->x+win->w && cursorWin.y >= win->y && cursorWin.y < win->y+32 && !(win->flags & FLAG_NOMOVE)) {
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
                        }
                        RavenEvent event;
                        event.type = RAVEN_MOUSE_PRESSED;
                        event.mouse.x = cursorWin.x-win->x;
                        event.mouse.y = cursorWin.y-win->y;
                        event.mouse.buttons = 1;
                        MQueue_SendToClient(msgQueue,win->owner,&event,sizeof(RavenEvent));
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
                            if(iconSelect == win) {
                                DoBoxAnimation(win->x+((win->w/2)-16),win->y,32,32,(fbInfo.width/2)-(560/2),(fbInfo.height/2)-(360/2),560,360,1);
                                TeamID hunterTeam = NewTeam("Hunter");
                                const char** args = malloc(3 * sizeof(uintptr_t));
                                args[0] = "/bin/hunter";
                                args[1] = "/";
                                args[2] = NULL;
                                LoadExecImage(hunterTeam, args, NULL);
                                free(args);
                                uint32_t* temp = iconSelect->frontBuf;
                                iconSelect->frontBuf = iconSelect->backBuf;
                                iconSelect->backBuf = temp;
                                Redraw(iconSelect->x, iconSelect->y, iconSelect->w, iconSelect->h);
                                iconSelect = NULL;
                            } else {
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
                            }
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