#include "Button.h"
#include <Common/Alloc.h>
#include <Common/String.h>
#include <Media/Graphics.h>

#define MAX(__x, __y) ((__x) > (__y) ? (__x) : (__y))

extern PSFHeader* RavenUnifont;
extern void* RavenIconPack;

typedef struct {
    char pressed;
    ButtonEventHandler onClick;
    int colorType;
    int hMargin;
    int vMargin;
    const char* text;
    const char* icon;
} UIButtonPrivateData;

typedef struct {
    char pressed;
    ButtonEventHandler onClick;
    const char* icon;
} UIIconButtonPrivateData;

static void IconButtonRedraw(void* self, RavenSession* session, ClientWindow* win, GraphicsContext* gfx) {
    UIWidget* widget = (UIWidget*)self;
    UIIconButtonPrivateData* private = (UIIconButtonPrivateData*)widget->privateData;
    Graphics_RenderIcon(gfx,RavenIconPack,private->icon,widget->x,widget->y,widget->w,widget->h,0xffe9e9ea);
}

static void ButtonRedraw(void* self, RavenSession* session, ClientWindow* win, GraphicsContext* gfx) {
    UIWidget* widget = (UIWidget*)self;
    UIButtonPrivateData* private = (UIButtonPrivateData*)widget->privateData;
    if(private->colorType == 1) {
        UIDrawRoundedBox(gfx,widget->x,widget->y,widget->w,widget->h,private->pressed ? 0xff2563eb : 0xff1d4ed8,0xff09090b);
    } else if(private->colorType == 0) {
        UIDrawRoundedBox(gfx,widget->x,widget->y,widget->w,widget->h,private->pressed ? 0xff27272a : 0xff18181b,0xff09090b);
    }
    int innerW = widget->w-(private->hMargin*2);
    int innerH = widget->h-(private->vMargin*2);
    int innerX = widget->x+((widget->w/2)-(innerW/2));
    int innerY = widget->y+((widget->h/2)-(innerH/2));
    if(private->icon != NULL) {
        Graphics_RenderIcon(gfx,RavenIconPack,private->icon,(widget->x+(widget->w/2))-16,innerY,32,32,0xffe9e9ea);
        Graphics_RenderCenteredString(gfx,widget->x+(widget->w/2),innerY+32,0xffe9e9ea,RavenUnifont,1,private->text);
    } else {
        Graphics_RenderCenteredString(gfx,widget->x+(widget->w/2),innerY,0xffe9e9ea,RavenUnifont,1,private->text);
    }
}

static void IconButtonEvent(void* self, RavenSession* session, ClientWindow* win, GraphicsContext* gfx, RavenEvent* event) {
    UIWidget* widget = (UIWidget*)self;
    UIIconButtonPrivateData* private = (UIIconButtonPrivateData*)widget->privateData;
    if(event->type == RAVEN_MOUSE_PRESSED) {
        private->pressed = 1;
    } else if(event->type == RAVEN_MOUSE_RELEASED) {
        int orig = private->pressed;
        private->pressed = 0;
        if(orig) {
            if(private->onClick != NULL) {
                private->onClick(session,win,widget->id);
            }
        }
    }
}

static void ButtonEvent(void* self, RavenSession* session, ClientWindow* win, GraphicsContext* gfx, RavenEvent* event) {
    UIWidget* widget = (UIWidget*)self;
    UIButtonPrivateData* private = (UIButtonPrivateData*)widget->privateData;
    if(event->type == RAVEN_MOUSE_PRESSED) {
        private->pressed = 1;
        widget->Redraw(self,session,win,gfx);
        RavenFlipArea(session,win,widget->x,widget->y,widget->w,widget->h);
    } else if(event->type == RAVEN_MOUSE_RELEASED) {
        int orig = private->pressed;
        private->pressed = 0;
        widget->Redraw(self,session,win,gfx);
        RavenFlipArea(session,win,widget->x,widget->y,widget->w,widget->h);
        if(orig) {
            if(private->onClick != NULL) {
                private->onClick(session,win,widget->id);
            }
        }
    }
}

int64_t NewButtonWidget(ClientWindow* win, int dest, int x, int y, int hMargin, int vMargin, int colorType, const char* text, const char* icon, ButtonEventHandler* onClick) {
    if(hMargin < 4)
        hMargin = 4;
    if(vMargin < 4)
        vMargin = 4;
    UIWidget* widget = malloc(sizeof(UIWidget));
    UIButtonPrivateData* private = malloc(sizeof(UIButtonPrivateData));
    widget->privateData = private;
    widget->x = x;
    widget->y = y;
    int innerW = icon != NULL ? MAX(32,8*strlen(text)) : 8*strlen(text);
    int innerH = icon != NULL ? 32+16 : 16;
    widget->w = innerW+(hMargin*2);
    widget->h = innerH+(vMargin*2);
    private->pressed = 0;
    private->hMargin = hMargin;
    private->vMargin = vMargin;
    private->icon = icon;
    private->text = text;
    private->onClick = onClick;
    private->colorType = colorType;
    widget->Redraw = &ButtonRedraw;
    widget->Event = &ButtonEvent;
    return UIAddWidget(win,widget,dest);
}

int64_t NewIconButtonWidget(ClientWindow* win, int dest, int x, int y, int w, int h, const char* icon, ButtonEventHandler* onClick) {
    UIWidget* widget = malloc(sizeof(UIWidget));
    UIIconButtonPrivateData* private = malloc(sizeof(UIIconButtonPrivateData));
    widget->privateData = private;
    widget->x = x;
    widget->y = y;
    widget->w = w;
    widget->h = h;
    private->pressed = 0;
    private->icon = icon;
    private->onClick = onClick;
    widget->Redraw = &IconButtonRedraw;
    widget->Event = &IconButtonEvent;
    return UIAddWidget(win,widget,dest);
}