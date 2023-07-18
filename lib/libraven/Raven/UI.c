#include "Raven.h"
#include <Media/Graphics.h>
#include <Common/Alloc.h>
#include <System/Thread.h>
#include <Common/String.h>
#include "Widget.h"
#include "UI.h"

PSFHeader* RavenKNXT;
PSFHeader* RavenUnifont;
PSFHeader* RavenTerminus;
void* RavenIconPack;

static ClientWindow* winHead = NULL;
static ClientWindow* winTail = NULL;

static ClientWindow* saveWin = NULL;
static SaveHandler saveFn = NULL;

ClientWindow* UIGetWindow(int64_t id) {
    ClientWindow* win = winHead;
    while(win != NULL) {
        if(win->id == id) {
            return win;
        }
        win = win->next;
    }
    return NULL;
}

void* UIGetWidget(ClientWindow* win, int64_t id) {
    UIWidget* widget = win->widgetHead;
    while(widget != NULL) {
        if(widget->id == id) {
            return widget;
        }
        widget = widget->next;
    }
    return NULL;
}

void UIRedrawWidgets(RavenSession* session, ClientWindow* win, GraphicsContext* gfx) {
    UIWidget* widget = win->widgetHead;
    while(widget != NULL) {
        widget->Redraw(widget,session,win,gfx);
        RavenFlipArea(session,win,widget->x,widget->y,widget->w,widget->h);
        widget = widget->next;
    }
}

void UIRedrawToolbarWidgets(RavenSession* session, ClientWindow* win, GraphicsContext* gfx) {
    UIWidget* widget = win->toolbarHead;
    int x = 2;
    while(widget != NULL) {
        widget->x = x;
        widget->y = 48-(widget->h/2);
        widget->Redraw(widget,session,win,gfx);
        RavenFlipArea(session,win,widget->x,widget->y,widget->w,widget->h);
        x += widget->w + 2;
        widget = widget->next;
    }
}

void UIDrawBaseWindow(RavenSession* session, ClientWindow* win, GraphicsContext* gfx, const char* title, const char* bg) {
    Graphics_DrawRect(gfx,0,0,gfx->w,gfx->h,0xff09090b);
    if(bg != NULL) {
        Graphics_RenderIcon(gfx,RavenIconPack,bg,gfx->w-192,gfx->h-192,256,256,0xff121214);
        for(int i=gfx->h-191; i < gfx->h; i+=2) {
            Graphics_DrawRect(gfx,gfx->w-192,i,256,1,0xff09090b);
        }
    }
    UIRedrawWidgets(session,win,gfx);
    if(win->toolbarHead != NULL) {
        Graphics_DrawRect(gfx,0,0,gfx->w,64,0xf018181b);
        Graphics_DrawRect(gfx,0,64,gfx->w,1,0xff27272a);
        UIRedrawToolbarWidgets(session,win,gfx);
    } else {
        Graphics_DrawRect(gfx,0,0,gfx->w,32,0xf018181b);
        Graphics_DrawRect(gfx,0,32,gfx->w,1,0xff27272a);
    }
    Graphics_DrawRectOutline(gfx,0,0,gfx->w,gfx->h,0xff27272a);

    Graphics_DrawRect(gfx,0,0,5,1,0x00000000);
    Graphics_DrawRect(gfx,0,0,1,5,0x00000000);
    Graphics_DrawRect(gfx,0,0,3,3,0x00000000);
    Graphics_DrawRect(gfx,2,2,1,1,0xff27272a);
    Graphics_DrawRect(gfx,1,3,1,2,0xff27272a);
    Graphics_DrawRect(gfx,3,1,2,1,0xff27272a);

    Graphics_DrawRect(gfx,gfx->w-5,0,5,1,0x00000000);
    Graphics_DrawRect(gfx,gfx->w-1,0,1,5,0x00000000);
    Graphics_DrawRect(gfx,gfx->w-3,0,3,3,0x00000000);
    Graphics_DrawRect(gfx,gfx->w-3,2,1,1,0xff27272a);
    Graphics_DrawRect(gfx,gfx->w-2,3,1,2,0xff27272a);
    Graphics_DrawRect(gfx,gfx->w-5,1,2,1,0xff27272a);

    Graphics_DrawRect(gfx,0,gfx->h-1,5,1,0x00000000);
    Graphics_DrawRect(gfx,0,gfx->h-5,1,5,0x00000000);
    Graphics_DrawRect(gfx,0,gfx->h-3,3,3,0x00000000);
    Graphics_DrawRect(gfx,2,gfx->h-3,1,1,0xff27272a);
    Graphics_DrawRect(gfx,1,gfx->h-5,1,2,0xff27272a);
    Graphics_DrawRect(gfx,3,gfx->h-2,2,1,0xff27272a);

    Graphics_DrawRect(gfx,gfx->w-5,gfx->h-1,5,1,0x00000000);
    Graphics_DrawRect(gfx,gfx->w-1,gfx->h-5,1,5,0x00000000);
    Graphics_DrawRect(gfx,gfx->w-3,gfx->h-3,3,3,0x00000000);
    Graphics_DrawRect(gfx,gfx->w-3,gfx->h-3,1,1,0xff27272a);
    Graphics_DrawRect(gfx,gfx->w-2,gfx->h-5,1,2,0xff27272a);
    Graphics_DrawRect(gfx,gfx->w-5,gfx->h-2,2,1,0xff27272a);

    Graphics_RenderIcon(gfx,RavenIconPack,"Window/Close",16-5,16-(9/2),16,9,0xffcbcbcf);
    Graphics_DrawRect(gfx,gfx->w-21,15,10,2,0xffcbcbcf);
    Graphics_RenderString(gfx,32+4,16-(RavenKNXT->height/2),0xffcbcbcf,RavenKNXT,1,title);
}

void UIDrawRoundedBox(GraphicsContext* gfx, int x, int y, int w, int h, uint32_t color, uint32_t backColor) {
    Graphics_DrawRect(gfx,x,y,w,h,color);
    // 0xff09090b
    // Top-Left
    Graphics_DrawRect(gfx,x,y,5,1,backColor);
    Graphics_DrawRect(gfx,x,y,1,5,backColor);
    Graphics_DrawRect(gfx,x,y,3,3,backColor);
    Graphics_DrawRect(gfx,x+2,y+2,1,1,color);
    // Top-Right
    Graphics_DrawRect(gfx,x+w-5,y,5,1,backColor);
    Graphics_DrawRect(gfx,x+w-1,y,1,5,backColor);
    Graphics_DrawRect(gfx,x+w-3,y,3,3,backColor);
    Graphics_DrawRect(gfx,x+w-3,y+2,1,1,color);
    // Bottom-Left
    Graphics_DrawRect(gfx,x,y+h-1,5,1,backColor);
    Graphics_DrawRect(gfx,x,y+h-5,1,5,backColor);
    Graphics_DrawRect(gfx,x,y+h-3,3,3,backColor);
    Graphics_DrawRect(gfx,x+2,y+h-3,1,1,color);
    // Bottom-Right
    Graphics_DrawRect(gfx,x+w-5,y+h-1,5,1,backColor);
    Graphics_DrawRect(gfx,x+w-1,y+h-5,1,5,backColor);
    Graphics_DrawRect(gfx,x+w-3,y+h-3,3,3,backColor);
    Graphics_DrawRect(gfx,x+w-3,y+h-3,1,1,color);
}

void UIAddWindow(RavenSession* session, ClientWindow* win, const char* title, const char* bg) {
    if(RavenKNXT == NULL) {
        RavenKNXT = Graphics_LoadFont("/System/Fonts/knxt.psf");
        RavenUnifont = Graphics_LoadFont("/System/Fonts/unifont.psf");
        RavenTerminus = Graphics_LoadFont("/System/Fonts/terminus.psf");
        RavenIconPack = Graphics_LoadIconPack("/System/Icons/IconPack");
    }
    if(winTail != NULL) {
        winTail->next = win;
    }
    win->prev = winTail;
    win->next = NULL;
    winTail = win;
    if(winHead == NULL) {
        winHead = win;
    }
    GraphicsContext* gfx = Graphics_NewContext(win->backBuf,win->w,win->h);
    win->gfx = gfx;
    UIDrawBaseWindow(session,win,gfx,title,bg);
    RavenFlipArea(session,win,0,0,win->w,win->h);
}

void UIRun(RavenSession* session) {
    while(1) {
        RavenEvent* event = RavenGetEvent(session);
        if(event->type == RAVEN_REDRAW_EVENT) {
            ClientWindow* win = UIGetWindow(event->id);
            UIRedrawWidgets(session,win,win->gfx);
        } else if(event->type == RAVEN_ICON_DROP && saveWin != NULL) {
            if(saveFn != NULL) {
                int len = strlen(((char*)event)+24);
                char* name = (char*)(((UIWidget*)saveWin->widgetTail)->privateData+1);
                char* finalPath = malloc(len+strlen(name)+1);
                memcpy(finalPath,((char*)event)+24,len);
                memcpy(finalPath+len,name,strlen(name)+1);
                saveFn(finalPath);
                free(finalPath);
                RavenRequestRedraw(session,*((int64_t*)(((void*)event)+16)));
            }
            if(saveWin->prev != NULL) {
                ((ClientWindow*)saveWin->prev)->next = saveWin->next;
            } else {
                winHead = saveWin->next;
            }
            if(saveWin->next != NULL) {
                ((ClientWindow*)saveWin->next)->prev = saveWin->prev;
            } else {
                winTail = saveWin->prev;
            }
            UIWidget* widget = saveWin->widgetHead;
            while(widget != NULL) {
                if(widget->privateData) {
                    free(widget->privateData);
                }
                void* next = widget->next;
                free(widget);
                widget = next;
            }
            widget = saveWin->toolbarHead;
            while(widget != NULL) {
                if(widget->privateData) {
                    free(widget->privateData);
                }
                void* next = widget->next;
                free(widget);
                widget = next;
            }
            RavenDestroyWindow(session,saveWin);
            saveWin = NULL;
            saveFn = NULL;
        } else if(event->type == RAVEN_MOUSE_PRESSED && event->mouse.x < 32 && event->mouse.y < 32) {
            ClientWindow* win = UIGetWindow(event->id);
            if(winHead == win && winTail == win) {
                CloseRavenSession(session);
                Exit(0);
            } else {
                if(win->prev != NULL) {
                    ((ClientWindow*)win->prev)->next = win->next;
                } else {
                    winHead = win->next;
                }
                if(win->next != NULL) {
                    ((ClientWindow*)win->next)->prev = win->prev;
                } else {
                    winTail = win->prev;
                }
                UIWidget* widget = win->widgetHead;
                while(widget != NULL) {
                    if(widget->privateData) {
                        free(widget->privateData);
                    }
                    void* next = widget->next;
                    free(widget);
                    widget = next;
                }
                widget = win->toolbarHead;
                while(widget != NULL) {
                    if(widget->privateData) {
                        free(widget->privateData);
                    }
                    void* next = widget->next;
                    free(widget);
                    widget = next;
                }
                RavenDestroyWindow(session,win);
            }
        } else if(event->type == RAVEN_MOUSE_PRESSED || event->type == RAVEN_MOUSE_RELEASED || event->type == RAVEN_KEY_PRESSED || event->type == RAVEN_KEY_RELEASED) {
            ClientWindow* win = UIGetWindow(event->id);
            UIWidget* widget = win->widgetHead;
            while(widget != NULL) {
                if(widget->Event != NULL) {
                    widget->Event(widget,session,win,win->gfx,event);
                }
                widget = widget->next;
            }
            widget = win->toolbarHead;
            while(widget != NULL) {
                if(widget->Event != NULL) {
                    widget->Event(widget,session,win,win->gfx,event);
                }
                widget = widget->next;
            }
        }
        free(event);
    }
}

int64_t UIAddWidget(ClientWindow* win, void* widget, int dest) {
    int64_t id = win->nextWidgetID++;
    ((UIWidget*)widget)->next = NULL;
    ((UIWidget*)widget)->id = id;
    if(dest == DEST_WIDGETS) {
        if(win->widgetTail != NULL) {
            ((UIWidget*)win->widgetTail)->next = widget;
        }
        ((UIWidget*)widget)->prev = win->widgetTail;
        win->widgetTail = widget;
        if(win->widgetHead == NULL) {
            win->widgetHead = widget;
        }
    } else if(dest == DEST_TOOLBAR) {
        if(win->toolbarTail != NULL) {
            ((UIWidget*)win->toolbarTail)->next = widget;
        }
        ((UIWidget*)widget)->prev = win->toolbarTail;
        win->toolbarTail = widget;
        if(win->toolbarHead == NULL) {
            win->toolbarHead = widget;
        }
    }
    return id;
}

void UIRemoveWidgets(ClientWindow* win) {
    UIWidget* widget = win->widgetHead;
    while(widget != NULL) {
        if(widget->privateData) {
            free(widget->privateData);
        }
        void* next = widget->next;
        free(widget);
        widget = next;
    }
    win->widgetHead = NULL;
    win->widgetTail = NULL;
    widget = win->toolbarHead;
    while(widget != NULL) {
        if(widget->privateData) {
            free(widget->privateData);
        }
        void* next = widget->next;
        free(widget);
        widget = next;
    }
    win->toolbarHead = NULL;
    win->toolbarTail = NULL;
}

#include "Widgets/Button.h"
#include "Widgets/Label.h"
#include "Widgets/Badge.h"
#include "Widgets/TextArea.h"

void UIAbout(RavenSession* session, ClientWindow* parent, const char* name, const char* icon, const char* version, const char* copyright, const char* author) {
    ClientWindow* aboutWin = NewRavenWindow(session,320,320,FLAG_ACRYLIC,parent->id);
    NewIconButtonWidget(aboutWin,DEST_WIDGETS,128,48,64,64,icon,NULL);
    NewLabelWidget(aboutWin,DEST_WIDGETS,(320/2)-((strlen(name)*16)/2),114,name,LABEL_MORE_LARGE);
    NewBadgeWidget(aboutWin,DEST_WIDGETS,(320/2)-(((strlen(version)*6)+16)/2),114+33,version,0);
    NewLabelWidget(aboutWin,DEST_WIDGETS,(320/2)-((strlen(copyright)*8)/2),114+65,copyright,LABEL_NORMAL);
    NewLabelWidget(aboutWin,DEST_WIDGETS,(320/2)-((strlen(author)*8)/2),114+65+16,author,LABEL_NORMAL);
    UIAddWindow(session,aboutWin,"About",NULL);
}

static void BeginSaveDrag(RavenSession* session, ClientWindow* win, void* button) {
    RavenPacket packet;
    packet.type = RAVEN_BEGIN_ICON_DRAG;
    packet.drag.id = win->id;
    packet.drag.iconX = ((UIWidget*)button)->x;
    packet.drag.iconY = ((UIWidget*)button)->y;
    packet.drag.loadDrag = 0;
    MQueue_SendToServer(session->raven,&packet,sizeof(RavenPacket));
}

void UISave(RavenSession* session, ClientWindow* parent, const char* icon, const char* name, SaveHandler save) {
    saveFn = save;
    saveWin = NewRavenWindow(session,150,128,FLAG_ACRYLIC,parent->id);
    NewIconButtonWidget(saveWin,DEST_WIDGETS,(saveWin->w/2)-16,33,32,32,icon,&BeginSaveDrag);
    NewTextBoxWidget(saveWin,DEST_WIDGETS,(saveWin->w/2)-((((saveWin->w-2)/8)*8)/2),65,(((saveWin->w-2)/8)*8),16,name);
    UIAddWindow(session,saveWin,"Save",NULL);
}