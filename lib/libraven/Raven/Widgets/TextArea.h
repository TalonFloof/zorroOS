#ifndef _LIBRAVEN_WIDGETS_LABEL_H
#include "../Widget.h"
#include "../Raven.h"
#include "../UI.h"

int64_t NewTextAreaWidget(ClientWindow* win, int dest, int x, int y, int w, int h);
int64_t NewTextBoxWidget(ClientWindow* win, int dest, int x, int y, int w, int h, const char* text);

#endif