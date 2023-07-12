#include "Label.h"
#include <Common/Alloc.h>
#include <Common/String.h>

extern PSFHeader* RavenUnifont;
extern PSFHeader* RavenKNXT;
extern PSFHeader* RavenTerminus;

typedef struct {
    const char* text;
    int badgeType;
} UIBadgePrivateData;

static void BadgeRedraw(void* self, RavenSession* session, ClientWindow* win, GraphicsContext* gfx) {
    UIWidget* widget = (UIWidget*)self;
    UIBadgePrivateData* private = (UIBadgePrivateData*)widget->privateData;
    //Graphics_RenderString(gfx,widget->x,widget->y,0xffffffff,RavenUnifont,1,private->text);
    // 7, 5, 4, 3, 2, 1, 1
    Graphics_DrawRect(gfx,widget->x,widget->y,widget->w,widget->h,0xff111822);

    Graphics_DrawRect(gfx,widget->x,widget->y,1,7,0xff09090b);
    Graphics_DrawRect(gfx,widget->x,widget->y+widget->h-7,1,7,0xff09090b);
    Graphics_DrawRect(gfx,widget->x+widget->w-1,widget->y,1,7,0xff09090b);
    Graphics_DrawRect(gfx,widget->x+widget->w-1,widget->y+widget->h-7,1,7,0xff09090b);

    Graphics_DrawRect(gfx,widget->x+1,widget->y,1,5,0xff09090b);
    Graphics_DrawRect(gfx,widget->x+1,widget->y+widget->h-5,1,5,0xff09090b);
    Graphics_DrawRect(gfx,widget->x+widget->w-2,widget->y,1,5,0xff09090b);
    Graphics_DrawRect(gfx,widget->x+widget->w-2,widget->y+widget->h-5,1,5,0xff09090b);

    Graphics_DrawRect(gfx,widget->x+2,widget->y,1,4,0xff09090b);
    Graphics_DrawRect(gfx,widget->x+2,widget->y+widget->h-4,1,4,0xff09090b);
    Graphics_DrawRect(gfx,widget->x+widget->w-3,widget->y,1,4,0xff09090b);
    Graphics_DrawRect(gfx,widget->x+widget->w-3,widget->y+widget->h-4,1,4,0xff09090b);

    Graphics_DrawRect(gfx,widget->x+3,widget->y,1,3,0xff09090b);
    Graphics_DrawRect(gfx,widget->x+3,widget->y+widget->h-3,1,3,0xff09090b);
    Graphics_DrawRect(gfx,widget->x+widget->w-4,widget->y,1,3,0xff09090b);
    Graphics_DrawRect(gfx,widget->x+widget->w-4,widget->y+widget->h-3,1,3,0xff09090b);

    Graphics_DrawRect(gfx,widget->x+4,widget->y,1,2,0xff09090b);
    Graphics_DrawRect(gfx,widget->x+4,widget->y+widget->h-2,1,2,0xff09090b);
    Graphics_DrawRect(gfx,widget->x+widget->w-5,widget->y,1,2,0xff09090b);
    Graphics_DrawRect(gfx,widget->x+widget->w-5,widget->y+widget->h-2,1,2,0xff09090b);

    Graphics_DrawRect(gfx,widget->x+5,widget->y,1,1,0xff09090b);
    Graphics_DrawRect(gfx,widget->x+5,widget->y+widget->h-1,1,1,0xff09090b);
    Graphics_DrawRect(gfx,widget->x+widget->w-6,widget->y,1,1,0xff09090b);
    Graphics_DrawRect(gfx,widget->x+widget->w-6,widget->y+widget->h-1,1,1,0xff09090b);

    Graphics_DrawRect(gfx,widget->x+6,widget->y,1,1,0xff09090b);
    Graphics_DrawRect(gfx,widget->x+6,widget->y+widget->h-1,1,1,0xff09090b);
    Graphics_DrawRect(gfx,widget->x+widget->w-7,widget->y,1,1,0xff09090b);
    Graphics_DrawRect(gfx,widget->x+widget->w-7,widget->y+widget->h-1,1,1,0xff09090b);

    Graphics_RenderString(gfx,widget->x+8,widget->y+((22/2)-6),0xff5897e4,RavenTerminus,1,private->text);
}

int64_t NewBadgeWidget(ClientWindow* win, int x, int y, const char* text, int badgeType) {
    UIWidget* widget = (UIWidget*)malloc(sizeof(UIWidget));
    UIBadgePrivateData* private = malloc(sizeof(UIBadgePrivateData));
    widget->privateData = private;
    widget->x = x;
    widget->y = y;
    // 8 px horizontal margin
    widget->w = (strlen(text)*6)+16;
    widget->h = 22;
    private->text = text;
    private->badgeType = badgeType;
    widget->Redraw = &BadgeRedraw;
    return UIAddWidget(win,widget);
}