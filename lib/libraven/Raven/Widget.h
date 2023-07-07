#ifndef _LIBRAVEN_WIDGET_H
#define _LIBRAVEN_WIDGET_H
#include <stdint.h>
#include <Media/Graphics.h>
#include "Raven.h"

typedef struct {
    int x;
    int y;
    int w;
    int h;
    void* privateData;
    void (*Redraw)(void* self, GraphicsContext* gfx);
    void (*Event)(void* self, RavenEvent* event);
} UIWidget;



#endif