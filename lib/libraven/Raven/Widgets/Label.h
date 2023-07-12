#ifndef _LIBRAVEN_WIDGETS_LABEL_H
#include "../Widget.h"
#include "../Raven.h"
#include "../UI.h"

#define LABEL_SMALL 0
#define LABEL_NORMAL 1
#define LABEL_LARGE 2
#define LABEL_EXTRA_LARGE 3

int64_t NewLabelWidget(ClientWindow* win, int x, int y, const char* text, int scale);

#endif