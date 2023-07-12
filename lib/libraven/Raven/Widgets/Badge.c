#include "Label.h"
#include <Common/Alloc.h>
#include <Common/String.h>

extern PSFHeader* RavenUnifont;
extern PSFHeader* RavenKNXT;

typedef struct {
    const char* text;
    int badgeType;
} UIBadgePrivateData;

static void BadgeRedraw(void* self, RavenSession* session, ClientWindow* win, GraphicsContext* gfx) {
    UIWidget* widget = (UIWidget*)self;
    UIBadgePrivateData* private = (UIBadgePrivateData*)widget->privateData;
    Graphics_RenderString(gfx,widget->x,widget->y,0xffffffff,RavenUnifont,1,private->text);
}

int64_t NewBadgeWidget(ClientWindow* win, int x, int y, const char* text, int badgeType) {
    UIWidget* widget = (UIWidget*)malloc(sizeof(UIWidget));
    UIBadgePrivateData* private = malloc(sizeof(UIBadgePrivateData));
    widget->privateData = private;
    widget->x = x;
    widget->y = y;
    widget->h = 12;
    private->text = text;
    private->badgeType = badgeType;
    widget->Redraw = &BadgeRedraw;
    return UIAddWidget(win,widget);
}