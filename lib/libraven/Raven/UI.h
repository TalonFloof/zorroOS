#ifndef _LIBRAVEN_UI_H
#define _LIBRAVEN_UI_H
#include "Raven.h"

#define DEST_WIDGETS 0
#define DEST_TOOLBAR 1

void UIDrawRoundedBox(GraphicsContext* gfx, int x, int y, int w, int h, uint32_t color);
void UIAddWindow(RavenSession* session, ClientWindow* win, const char* title, const char* bg);
void UIRun(RavenSession* session);
void UIRedrawWidgets(RavenSession* session, ClientWindow* win, GraphicsContext* gfx);
int64_t UIAddWidget(ClientWindow* win, void* widget, int dest);

#endif