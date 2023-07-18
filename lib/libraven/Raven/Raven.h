#ifndef _LIBRAVEN_RAVEN_RAVEN_H
#define _LIBRAVEN_RAVEN_RAVEN_H
#include <stdint.h>
#include <Filesystem/MQueue.h>
#include <Media/Graphics.h>

typedef enum {
    RAVEN_INVALID_MESSAGE = 0,
    RAVEN_ACK = 1,
    RAVEN_OKEE_BYEEEE = 2, // the furry version of a goodbye message :3
    RAVEN_CREATE_WINDOW = 3,
    RAVEN_MOVE_WINDOW = 4,
    RAVEN_GET_RESOLUTION = 5,
    RAVEN_DESTROY_WINDOW = 7,
    RAVEN_SET_BACKGROUND = 8,
    RAVEN_FLIP_BUFFER = 9,
    RAVEN_SET_PATH = 10,
    RAVEN_BEGIN_ICON_DRAG = 11,
    RAVEN_REDRAW = 12,
} RavenPacketType;

typedef enum {
    RAVEN_INVALID_EVENT = 0,
    RAVEN_KEY_PRESSED = 1,
    RAVEN_KEY_RELEASED = 2,
    RAVEN_MOUSE_MOVE = 3,
    RAVEN_MOUSE_PRESSED = 4,
    RAVEN_MOUSE_RELEASED = 5,
    RAVEN_ICON_DROP = 6,
    RAVEN_REDRAW_EVENT = 7,
} RavenEventType;

typedef struct {
    int flags;
    int w;
    int h;
    int64_t creator;
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
    int iconX;
    int iconY;
    char loadDrag;
} RavenBeginDrag;

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
    int64_t id;
    uint8_t padding; // To prevent it from having the same size as a CreateWindowResponse
    // ^^^ 24 bytes
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
        RavenBeginDrag drag;
    };
} RavenPacket;

///////////////////////////////////////////////////////////
typedef struct {
    MQueue* raven;
} RavenSession;

typedef struct {
    void* prev;
    void* next;
    int64_t id;
    int w;
    int h;
    int flags;
    int64_t backID;
    uint32_t* backBuf;
    void* widgetHead;
    void* widgetTail;
    void* toolbarHead;
    void* toolbarTail;
    GraphicsContext* gfx;
    int64_t nextWidgetID;
} ClientWindow;

#define FLAG_OPAQUE 1
#define FLAG_NOMOVE 2
#define FLAG_ACRYLIC 4
#define FLAG_RESIZE 8

RavenSession* NewRavenSession();
void CloseRavenSession(RavenSession* session);
ClientWindow* NewRavenWindow(RavenSession* s, int w, int h, int flags, int64_t creator);
void RavenMoveWindow(RavenSession* s, ClientWindow* win, int x, int y);
void RavenDestroyWindow(RavenSession* s, ClientWindow* win);
void RavenGetResolution(RavenSession* s, int* w, int* h);
void RavenFlipArea(RavenSession* s, ClientWindow* win, int x, int y, int w, int h);
RavenEvent* RavenGetEvent(RavenSession* s);
void RavenRequestRedraw(RavenSession* s, int64_t winID);

#endif