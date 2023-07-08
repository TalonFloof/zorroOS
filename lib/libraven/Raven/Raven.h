#ifndef _LIBRAVEN_RAVEN_RAVEN_H
#define _LIBRAVEN_RAVEN_RAVEN_H
#include <stdint.h>
#include <Filesystem/MQueue.h>
#include <Media/Graphics.h>

typedef enum {
    RAVEN_INVALID_MESSAGE,
    RAVEN_ACK,
    RAVEN_OKEE_BYEEEE, // the furry version of a goodbye message :3
    RAVEN_CREATE_WINDOW,
    RAVEN_MOVE_WINDOW,
    RAVEN_GET_RESOLUTION,
    RAVEN_DESTROY_WINDOW,
    RAVEN_FLIP_BUFFER,
} RavenPacketType;

typedef enum {
    RAVEN_INVALID_EVENT,
    RAVEN_KEY_PRESSED,
    RAVEN_KEY_RELEASED,
    RAVEN_MOUSE_PRESSED,
    RAVEN_MOUSE_RELEASED,
} RavenEventType;

typedef struct {
    int flags;
    int w;
    int h;
} RavenCreateWindow;

typedef struct {
    int64_t id;
    int x;
    int y;
    int w;
    int h;
} RavenFlipBuffer;

typedef struct {
    int64_t id;
    int x;
    int y;
} RavenMoveWindowData;

typedef struct {
    int64_t id;
    int64_t backBuf;
} RavenCreateWindowResponse;

typedef struct {
    int w;
    int h;
} RavenGetResolutionResponse;

typedef struct {
    uint32_t key;
    uint32_t rune;
} RavenKeyEvent;

typedef struct {
    int x;
    int y;
    uint32_t buttons;
} RavenMouseEvent;

typedef struct {
    RavenEventType type;
    union {
        RavenKeyEvent key;
        RavenMouseEvent mouse;
    };
} RavenEvent;

typedef struct {
    RavenPacketType type;
    union {
        RavenCreateWindow create;
        RavenMoveWindowData move;
        RavenFlipBuffer flipBuffer;
    };
} RavenPacket;
///////////////////////////////////////////////////////////
typedef struct {
    MQueue* raven;
} RavenSession;

typedef struct {
    int64_t id;
    int w;
    int h;
    int flags;
    int64_t backID;
    uint32_t* backBuf;
    void* widgetHead;
    void* widgetTail;
    int64_t nextWidgetID;
} ClientWindow;

#define FLAG_OPAQUE 1
#define FLAG_NOMOVE 2
#define FLAG_ACRYLIC 4
#define FLAG_RESIZE 8

RavenSession* NewRavenSession();
void CloseRavenSession(RavenSession* session);
ClientWindow* NewRavenWindow(RavenSession* s, int w, int h, int flags);
void RavenMoveWindow(RavenSession* s, ClientWindow* win, int x, int y);
void RavenGetResolution(RavenSession* s, int* w, int* h);
void RavenFlipArea(RavenSession* s, ClientWindow* win, int x, int y, int w, int h);
RavenEvent* RavenGetEvent(RavenSession* s);
void RavenDrawWindowDecoration(ClientWindow* win, GraphicsContext* gfx);

#endif