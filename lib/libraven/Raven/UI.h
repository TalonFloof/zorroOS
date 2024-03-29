#ifndef _LIBRAVEN_UI_H
#define _LIBRAVEN_UI_H
#include "Raven.h"

#define DEST_WIDGETS 0
#define DEST_TOOLBAR 1

typedef void (*SaveHandler)(char*);
typedef void (*LoadHandler)(char*);
void* UIGetWidget(ClientWindow* win, int64_t id);
void UIDrawRoundedBox(GraphicsContext* gfx, int x, int y, int w, int h, uint32_t color, uint32_t backColor);
void UIAddWindow(RavenSession* session, ClientWindow* win, const char* title, const char* bg);
void UIDrawBaseWindow(RavenSession* session, ClientWindow* win, GraphicsContext* gfx, const char* title, const char* bg);
void UIRunOnLoad(LoadHandler load);
void UIRun(RavenSession* session);
void UIRedrawWidgets(RavenSession* session, ClientWindow* win, GraphicsContext* gfx);
int64_t UIAddWidget(ClientWindow* win, void* widget, int dest);
void UIRemoveWidgets(ClientWindow* win);
void UIAbout(RavenSession* session, ClientWindow* parent, const char* name, const char* icon, const char* version, const char* copyright, const char* author);
void UISave(RavenSession* session, ClientWindow* parent, const char* icon, const char* name, SaveHandler save);

#endif