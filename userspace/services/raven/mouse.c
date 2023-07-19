#include "mouse.h"
#include <System/Thread.h>
#include <Filesystem/Filesystem.h>
#include <Common/Spinlock.h>
#include <Filesystem/MQueue.h>
#include <System/Team.h>
#include <Common/Alloc.h>
#include "raven.h"
#include <stdbool.h>
#include <Common/String.h>

bool lButton = false;
int winX = 0;
int winY = 0;
int iconStartX = 0;
int iconStartY = 0;
bool loadDrag = false;
Window* winDrag = NULL;
char* iconDragPath = NULL;

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
                if(iconDrag != NULL) {
                    Redraw(oldX - winX, oldY - winY, 32, 32);
                    renderInvertOutline(cursorWin.x - winX, cursorWin.y - winY, 32, 32);
                } else if (winDrag != NULL) {
                    renderInvertOutline(oldX - winX, oldY - winY, winDrag->w, winDrag->h);
                    renderInvertOutline(cursorWin.x - winX, cursorWin.y - winY, winDrag->w, winDrag->h);
                } else if(winFocus != NULL) {
                    if(cursorWin.x >= winFocus->x && cursorWin.x < winFocus->x+winFocus->w && cursorWin.y >= winFocus->y && cursorWin.y < winFocus->y+winFocus->h) {
                        RavenEvent event;
                        event.type = RAVEN_MOUSE_MOVE;
                        event.id = winFocus->id;
                        event.mouse.x = cursorWin.x-winFocus->x;
                        event.mouse.y = cursorWin.y-winFocus->y;
                        event.mouse.buttons = 0;
                        MQueue_SendToClient(msgQueue,winFocus->owner,&event,sizeof(RavenEvent));
                    }
                }
            }
            if ((buttons & 1) == 0 && lButton) {
                if(iconDrag != NULL) {
                    Redraw(cursorWin.x-winX,cursorWin.y-winY,32,32);
                    SpinlockAcquire(&windowLock);
                    Window* win = winTail;
                    bool clicked = false;
                    while(win != NULL) {
                        if(cursorWin.x >= win->x && cursorWin.x <= win->x+win->w && cursorWin.y >= win->y && cursorWin.y <= win->y+win->h) {
                            if(win->path != NULL && !loadDrag) {
                                void* response = malloc(strlen(win->path)+25);
                                *((RavenEventType*)response) = RAVEN_ICON_DROP;
                                *((int64_t*)(response+8)) = iconDrag->id;
                                *((int64_t*)(response+16)) = win->id;
                                memcpy(response+24,win->path,strlen(win->path)+1);
                                MQueue_SendToClient(msgQueue,iconDrag->owner,response,strlen(win->path)+25);
                                free(response);
                                clicked = true;
                            } else if(loadDrag && win->path == NULL) {
                                void* response = malloc(strlen(iconDragPath)+25);
                                *((RavenEventType*)response) = RAVEN_ICON_DRAG;
                                *((int64_t*)(response+8)) = win->id;
                                memcpy(response+24,iconDragPath,strlen(iconDragPath)+1);
                                MQueue_SendToClient(msgQueue,win->owner,response,strlen(iconDragPath)+25);
                                free(response);
                                clicked = true;
                            }
                            break;
                        }
                        win = win->prev;
                    }
                    SpinlockRelease(&windowLock);
                    if(!clicked) {
                        DoBoxAnimation(cursorWin.x-winX,cursorWin.y-winY,32,32,iconStartX,iconStartY,32,32,0);
                    }
                    iconDrag = NULL;
                    if(iconDragPath != NULL) {
                        free(iconDragPath);
                        iconDragPath = NULL;
                    }
                } else if(winDrag != NULL) {
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
                } else if(cursorWin.x >= dockWin.x && cursorWin.x < dockWin.x+dockWin.w && cursorWin.y >= dockWin.y && cursorWin.y < dockWin.y+dockWin.h) {
                    int i = 0;
                    DockItem* item = dockHead;
                    while(item != NULL) {
                        if(cursorWin.x >= dockWin.x+i && cursorWin.x < dockWin.x+i+48) {
                            item->pressed = 0;
                            RedrawDock();
                            if(item->type == DOCK_APPLICATION) {
                                TeamID team = NewTeam("Launched Application");
                                LoadExecImage(team,(const char*[]){item->app.path,NULL},NULL);
                            } else if(item->type == DOCK_WINDOW) {
                                DoBoxAnimation(dockWin.x,dockWin.y,dockWin.w,dockWin.h,item->win->x,item->win->y,item->win->w,item->win->h,1);
                                if(item->prev != NULL) {
                                    ((DockItem*)item->prev)->next = item->next;
                                } else {
                                    dockHead = item->next;
                                }
                                if(item->next != NULL) {
                                    ((DockItem*)item->next)->prev = item->prev;
                                } else {
                                    dockTail = item->prev;
                                }
                                SpinlockAcquire(&windowLock);
                                item->win->prev = winTail;
                                item->win->next = NULL;
                                if(winTail != NULL) {
                                    winTail->next = item->win;
                                }
                                winTail = item->win;
                                if(winHead == NULL) {
                                    winHead = item->win;
                                }
                                SpinlockRelease(&windowLock);
                                Redraw(item->win->x,item->win->y,item->win->w,item->win->h);
                                free(item);
                                dockItems -= 1;
                                RedrawDock();
                            }
                            break;
                        }
                        item = item->next;
                        i += 48;
                    }
                } else if (winFocus != NULL) {
                    if(cursorWin.x >= winFocus->x && cursorWin.x <= winFocus->x+winFocus->w && cursorWin.y >= winFocus->y && cursorWin.y <= winFocus->y+winFocus->h) {
                        RavenEvent event;
                        event.type = RAVEN_MOUSE_RELEASED;
                        event.id = winFocus->id;
                        event.mouse.x = cursorWin.x-winFocus->x;
                        event.mouse.y = cursorWin.y-winFocus->y;
                        event.mouse.buttons = 0;
                        MQueue_SendToClient(msgQueue,winFocus->owner,&event,sizeof(RavenEvent));
                    }
                }
            } else if ((buttons & 1) != 0 && !lButton) {
                if(cursorWin.x >= dockWin.x && cursorWin.x < dockWin.x+dockWin.w && cursorWin.y >= dockWin.y && cursorWin.y < dockWin.y+dockWin.h) {
                    int i = 0;
                    DockItem* item = dockHead;
                    while(item != NULL) {
                        if(cursorWin.x >= dockWin.x+i && cursorWin.x < dockWin.x+i+48) {
                            item->pressed = 1;
                            RedrawDock();
                            break;
                        }
                        item = item->next;
                        i += 48;
                    }
                } else {
                    SpinlockAcquire(&windowLock);
                    Window* win = winTail;
                    bool clicked = false;
                    while(win != NULL) {
                        if(cursorWin.x >= win->x+32 && cursorWin.x < win->x+win->w-32 && cursorWin.y >= win->y && cursorWin.y < win->y+32 && !(win->flags & FLAG_NOMOVE)) {
                            winDrag = win;
                            winX = cursorWin.x - win->x;
                            winY = cursorWin.y - win->y;
                            renderInvertOutline(cursorWin.x - winX,cursorWin.y - winY,win->w,win->h);
                            clicked = true;
                            break;
                        } else if(cursorWin.x >= win->x+win->w-32 && cursorWin.x < win->x+win->w && cursorWin.y >= win->y && cursorWin.y < win->y+32) {
                            SpinlockRelease(&windowLock);
                            NewDockWindow(win);
                            if(winFocus == win) {
                                winFocus = NULL;
                            }
                            SpinlockAcquire(&windowLock);
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
                            event.id = winFocus->id;
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
                }
            }
            lButton = (buttons & 1) != 0;
        } else {
            RyuLog("WARNING: /dev/ps2mouse returned unusual value!\n");
        }
    }
}