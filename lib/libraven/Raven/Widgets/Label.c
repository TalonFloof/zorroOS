#include "Label.h"
#include <Common/Alloc.h>
#include <Common/String.h>

extern PSFHeader* RavenTerminus;
extern PSFHeader* RavenUnifont;
extern PSFHeader* RavenKNXT;

typedef struct {
    const char* text;
    int scale;
} UILabelPrivateData;

static void LabelRedraw(void* self, RavenSession* session, ClientWindow* win, GraphicsContext* gfx) {
    UIWidget* widget = (UIWidget*)self;
    UILabelPrivateData* private = (UILabelPrivateData*)widget->privateData;
    if(private->scale == LABEL_SMALL) {
        Graphics_RenderString(gfx,widget->x,widget->y,0xffe9e9ea,RavenTerminus,1,private->text);
    } else if(private->scale == LABEL_NORMAL) {
        Graphics_RenderString(gfx,widget->x,widget->y,0xffe9e9ea,RavenUnifont,1,private->text);
    } else if(private->scale == LABEL_LARGE) {
        Graphics_RenderString(gfx,widget->x,widget->y,0xffe9e9ea,RavenKNXT,1,private->text);
    } else if(private->scale == LABEL_MORE_LARGE) {
        Graphics_RenderString(gfx,widget->x,widget->y,0xffe9e9ea,RavenUnifont,2,private->text);
    } else if(private->scale == LABEL_EXTRA_LARGE) {
        Graphics_RenderString(gfx,widget->x,widget->y,0xffe9e9ea,RavenKNXT,2,private->text);
    }
}

int64_t NewLabelWidget(ClientWindow* win, int dest, int x, int y, const char* text, int scale) {
    UIWidget* widget = (UIWidget*)malloc(sizeof(UIWidget));
    UILabelPrivateData* private = malloc(sizeof(UILabelPrivateData));
    widget->privateData = private;
    widget->x = x;
    widget->y = y;
    if(scale == LABEL_SMALL) {
        widget->w = 6*strlen(text);
        widget->h = 12;
    } else if(scale == LABEL_NORMAL) {
        widget->w = 8*strlen(text);
        widget->h = 16;
    } else if(scale == LABEL_LARGE) {
        widget->w = 9*strlen(text);
        widget->h = 20;
    } else if(scale == LABEL_MORE_LARGE) {
        widget->w = 16*strlen(text);
        widget->h = 32;
    } else if(scale == LABEL_EXTRA_LARGE) {
        widget->w = (9*2)*strlen(text);
        widget->h = 40;
    }
    private->text = text;
    private->scale = scale;
    widget->Redraw = &LabelRedraw;
    return UIAddWidget(win,widget,dest);
}