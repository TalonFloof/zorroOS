#include "Raven.h"
#include <Media/Graphics.h>
#include <Common/Alloc.h>
#include "Widget.h"

PSFHeader* RavenKNXT;
PSFHeader* RavenUnifont;
void* RavenIconPack;

void UIRedrawWidgets(RavenSession* session, ClientWindow* win, GraphicsContext* gfx) {
    UIWidget* widget = win->widgetHead;
    while(widget != NULL) {
        widget->Redraw(widget,session,win,gfx);
        RavenFlipArea(session,win,widget->x,widget->y,widget->w,widget->h);
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
    Graphics_DrawRect(gfx,0,0,gfx->w,32,0xe018181b);
    Graphics_DrawRect(gfx,0,0,32,32,0xe027272a);
    Graphics_DrawRectOutline(gfx,0,0,gfx->w,gfx->h,0xff27272a);
    Graphics_DrawRect(gfx,0,32,gfx->w,1,0xff27272a);

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

    Graphics_RenderString(gfx,32+4,16-(RavenKNXT->height/2),0xffcbcbcf,RavenKNXT,1,title);
}

void UIDrawRoundedBox(GraphicsContext* gfx, int x, int y, int w, int h, uint32_t color) {
    Graphics_DrawRect(gfx,x,y,w,h,color);

    // Top-Left
    Graphics_DrawRect(gfx,x,y,5,1,0xff09090b);
    Graphics_DrawRect(gfx,x,y,1,5,0xff09090b);
    Graphics_DrawRect(gfx,x,y,3,3,0xff09090b);
    Graphics_DrawRect(gfx,x+2,y+2,1,1,color);
    // Top-Right
    Graphics_DrawRect(gfx,x+w-5,y,5,1,0xff09090b);
    Graphics_DrawRect(gfx,x+w-1,y,1,5,0xff09090b);
    Graphics_DrawRect(gfx,x+w-3,y,3,3,0xff09090b);
    Graphics_DrawRect(gfx,x+w-3,y+2,1,1,color);
    // Bottom-Left
    Graphics_DrawRect(gfx,x,y+h-1,5,1,0xff09090b);
    Graphics_DrawRect(gfx,x,y+h-5,1,5,0xff09090b);
    Graphics_DrawRect(gfx,x,y+h-3,3,3,0xff09090b);
    Graphics_DrawRect(gfx,x+2,y+h-3,1,1,color);
    // Bottom-Right
    Graphics_DrawRect(gfx,x+w-5,y+h-1,5,1,0xff09090b);
    Graphics_DrawRect(gfx,x+w-1,y+h-5,1,5,0xff09090b);
    Graphics_DrawRect(gfx,x+w-3,y+h-3,3,3,0xff09090b);
    Graphics_DrawRect(gfx,x+w-3,y+h-3,1,1,color);
}

void UIRun(RavenSession* session, ClientWindow* win, const char* title, const char* bg) {
    RavenKNXT = Graphics_LoadFont("/System/Fonts/knxt.psf");
    RavenUnifont = Graphics_LoadFont("/System/Fonts/unifont.psf");
    RavenIconPack = Graphics_LoadIconPack("/System/Icons/IconPack");
    GraphicsContext* gfx = Graphics_NewContext(win->backBuf,win->w,win->h);
    UIDrawBaseWindow(session,win,gfx,title,bg);
    RavenFlipArea(session,win,0,0,win->w,win->h);
    while(1) {
        RavenEvent* event = RavenGetEvent(session);
        if(event->type == RAVEN_MOUSE_PRESSED || event->type == RAVEN_MOUSE_RELEASED) {
            UIWidget* widget = win->widgetHead;
            while(widget != NULL) {
                if(widget->Event != NULL) {
                    if(event->mouse.x >= widget->x && event->mouse.x < widget->x+widget->w && event->mouse.y >= widget->y && event->mouse.y < widget->y+widget->h) {
                        widget->Event(widget,session,win,gfx,event);
                    }
                }
                widget = widget->next;
            }
        }
        free(event);
    }
    free(gfx);
}

int64_t UIAddWidget(ClientWindow* win, void* widget) {
    int64_t id = win->nextWidgetID++;
    ((UIWidget*)widget)->id = id;
    if(win->widgetTail != NULL) {
        ((UIWidget*)win->widgetTail)->next = widget;
    }
    ((UIWidget*)widget)->prev = win->widgetTail;
    win->widgetTail = widget;
    if(win->widgetHead == NULL) {
        win->widgetHead = widget;
    }
    return id;
}