#ifndef _LIBRAVEN_RAVEN_RAVEN_H
#define _LIBRAVEN_RAVEN_RAVEN_H
#include <stdint.h>
#include <Filesystem/MQueue.h>

typedef enum {
    RAVEN_INVALID_MESSAGE,
    RAVEN_ACK,
    RAVEN_OKEE_BYEEEE, // the furry version of a goodbye message :3
    RAVEN_CREATE_WINDOW,
    RAVEN_DESTROY_WINDOW,
    RAVEN_FLIP_BUFFER,
} RavenPacketType;

typedef enum {
    RAVEN_INVALID_EVENT,
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
    int64_t backBuf;
} RavenCreateWindowResponse;

typedef struct {
    RavenPacketType type;
    union {
        RavenCreateWindow create;
    };
} RavenPacket;

typedef struct {
    RavenEventType type;
    union {
        
    };
} RavenEvent;
///////////////////////////////////////////////////////////
typedef struct {
    MQueue* raven;
} RavenSession;

typedef struct {
    int64_t id;
    int w;
    int h;
    int64_t backID;
    uint32_t* backBuf;
} ClientWindow;

#define FLAG_OPAQUE 1
#define FLAG_NOMOVE 2
#define FLAG_ACRYLIC 4
#define FLAG_RESIZE 8

RavenSession* NewRavenSession();
ClientWindow* NewRavenWindow(RavenSession* s, int w, int h, int flags);

#endif