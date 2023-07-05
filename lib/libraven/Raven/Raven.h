#ifndef _LIBRAVEN_RAVEN_RAVEN_H
#define _LIBRAVEN_RAVEN_RAVEN_H
#include <stdint.h>

enum CompositorMesgType {
    RAVEN_INVALID,
    RAVEN_ACK,
    RAVEN_OKEE_BYEEEE, // the furry version of a goodbye message :3
    RAVEN_CREATE_WINDOW,
    RAVEN_DESTROY_WINDOW,
    RAVEN_FLIP_BUFFER,
};

typedef struct {
    
} CompositorPacket;

#endif