#ifndef _LIBRAVEN_WIDGETS_BUTTON_H
#include "../Widget.h"
#include "../Raven.h"
#include "../UI.h"

typedef void (*ButtonEventHandler)(RavenSession*, ClientWindow*, uint64_t);
int64_t NewButtonWidget(ClientWindow* win, int x, int y, int hMargin, int vMargin, int colorType, const char* text, const char* icon, ButtonEventHandler* onClick);

#endif