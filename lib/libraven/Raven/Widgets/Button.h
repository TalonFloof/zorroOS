#ifndef _LIBRAVEN_WIDGETS_BUTTON_H
#include "../Widget.h"
#include "../Raven.h"
#include "../UI.h"

typedef void (*ButtonEventHandler)(RavenSession*, ClientWindow*, void*);
int64_t NewButtonWidget(ClientWindow* win, int dest, int x, int y, int hMargin, int vMargin, int colorType, const char* text, const char* icon, ButtonEventHandler onClick);
int64_t NewIconButtonWidget(ClientWindow* win, int dest, int x, int y, int w, int h, const char* icon, ButtonEventHandler onClick);

#endif