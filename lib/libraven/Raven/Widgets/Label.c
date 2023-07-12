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
    if(private->scale == 0) {
        Graphics_RenderString(gfx,widget->x,widget->y,0xffe9e9ea,RavenTerminus,1,private->text);
    } else if(private->scale == 1) {
        Graphics_RenderString(gfx,widget->x,widget->y,0xffe9e9ea,RavenUnifont,1,private->text);
    } else if(private->scale == 2) {
        Graphics_RenderString(gfx,widget->x,widget->y,0xffe9e9ea,RavenKNXT,1,private->text);
    } else if(private->scale == 3) {
        Graphics_RenderString(gfx,widget->x,widget->y,0xffe9e9ea,RavenKNXT,2,private->text);
    }
}

int64_t NewLabelWidget(ClientWindow* win, int x, int y, const char* text, int scale) {
    UIWidget* widget = (UIWidget*)malloc(sizeof(UIWidget));
    UILabelPrivateData* private = malloc(sizeof(UILabelPrivateData));
    widget->privateData = private;
    widget->x = x;
    widget->y = y;
    if(scale == 0) {
        widget->w = 6*strlen(text);
        widget->h = 12;
    } else if(scale == 1) {
        widget->w = 8*strlen(text);
        widget->h = 16;
    } else if(scale == 2) {
        widget->w = 9*strlen(text);
        widget->h = 20;
    } else if(scale == 3) {
        widget->w = (9*2)*strlen(text);
        widget->h = 40;
    }
    private->text = text;
    private->scale = scale;
    widget->Redraw = &LabelRedraw;
    return UIAddWidget(win,widget);
}