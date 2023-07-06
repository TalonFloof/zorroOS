#include "Raven.h"
#include <Media/Graphics.h>
#include <Common/Alloc.h>

void UIDrawBaseWindow(GraphicsContext* gfx) {
    Graphics_DrawRect(gfx,0,0,gfx->w,gfx->h,0xff09090b);
    Graphics_DrawRect(gfx,0,0,gfx->w,64,0xc018181b);
    Graphics_DrawRectOutline(gfx,0,0,gfx->w,gfx->h,0xff27272a);
    Graphics_DrawRect(gfx,0,64,gfx->w,1,0xff27272a);

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
}

void UIRun(RavenSession* session, ClientWindow* win) {
    GraphicsContext* gfx = Graphics_NewContext(win->backBuf,win->w,win->h);
    UIDrawBaseWindow(gfx);
    RavenFlipArea(session,win,0,0,win->w,win->h);
    while(1) {
        RavenEvent* event = RavenGetEvent(session);
        free(event);
    }
}