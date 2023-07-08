#ifndef _LIBRAVEN_WIDGETS_BUTTON_H
#include "../Widget.h"
#include "../Raven.h"
#include "../UI.h"

typedef void (*ButtonEventHandler)(ClientWindow*, uint64_t);
int64_t NewButtonWidget(ClientWindow* win, int x, int y, int hMargin, int vMargin, const char* text, const char* icon, ButtonEventHandler* onClick);

#endif