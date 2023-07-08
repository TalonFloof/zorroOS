#ifndef _LIBRAVEN_WIDGET_H
#define _LIBRAVEN_WIDGET_H
#include <stdint.h>
#include <Media/Graphics.h>
#include "Raven.h"

typedef struct {
    void* prev;
    void* next;
    int64_t id;
    int x;
    int y;
    int w;
    int h;
    void* privateData;
    void (*Redraw)(void* self, RavenSession* session, ClientWindow* win, GraphicsContext* gfx);
    void (*Event)(void* self, RavenSession* session, ClientWindow* win, GraphicsContext* gfx, RavenEvent* event);
} UIWidget;

#endif