#include "Image.h"
#include <Common/String.h>
#include <Common/Alloc.h>

static void ImageRedraw(void* self, RavenSession* session, ClientWindow* win, GraphicsContext* gfx) {
    UIWidget* widget = (UIWidget*)self;
    uint32_t* image = (uint32_t*)widget->privateData;
    for(int i=widget->y; i < widget->y+widget->h; i++) {
        memcpy(&gfx->buf[(i*gfx->w)+widget->x],&image[(i-widget->y)*widget->w],4*widget->w);
    }
}

int64_t NewImageWidget(ClientWindow* win, int dest, int x, int y, int w, int h, uint32_t* image) {
    UIWidget* widget = (UIWidget*)malloc(sizeof(UIWidget));
    widget->privateData = image;
    widget->x = x;
    widget->y = y;
    widget->w = w;
    widget->h = h;
    widget->Redraw = &ImageRedraw;
    return UIAddWidget(win,widget,dest);
}