#ifndef _LIBRAVEN_UI_H
#define _LIBRAVEN_UI_H
#include "Raven.h"

void UIDrawRoundedBox(GraphicsContext* gfx, int x, int y, int w, int h, uint32_t color);
void UIRun(RavenSession* session, ClientWindow* win);
void UIRedrawWidgets(RavenSession* session, ClientWindow* win, GraphicsContext* gfx);
int64_t UIAddWidget(ClientWindow* win, void* widget);

#endif