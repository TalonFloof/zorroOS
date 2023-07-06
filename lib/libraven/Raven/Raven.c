#include "Raven.h"
#include <Common/Alloc.h>
#include <System/SharedMemory.h>
#include <Media/Graphics.h>

RavenSession* NewRavenSession() {
    RavenSession* s = malloc(sizeof(RavenSession));
    s->raven = MQueue_Connect("/dev/mqueue/Raven");
    return s;
}

ClientWindow* NewRavenWindow(RavenSession* s, int w, int h, int flags) {
    RavenPacket packet;
    packet.type = RAVEN_CREATE_WINDOW;
    packet.create.w = w;
    packet.create.h = h;
    packet.create.flags = flags;
    MQueue_SendToServer(s->raven,&packet,sizeof(RavenPacket));
    size_t size;
    RavenCreateWindowResponse* response = MQueue_RecieveFromServer(s->raven,&size);
    if(size < sizeof(RavenCreateWindowResponse)) {
        free(response);
        return NULL;
    }
    ClientWindow* win = malloc(sizeof(ClientWindow));
    win->id = response->id;
    win->backID = response->backBuf;
    win->backBuf = MapSharedMemory(response->backBuf);
    win->w = w;
    win->h = h;
    win->flags = flags;
    free(response);
    return win;
}

void RavenFlipArea(RavenSession* s, ClientWindow* win, int x, int y, int w, int h) {
    RavenPacket packet;
    packet.type = RAVEN_FLIP_BUFFER;
    packet.flipBuffer.id = win->id;
    packet.flipBuffer.x = x;
    packet.flipBuffer.y = y;
    packet.flipBuffer.w = w;
    packet.flipBuffer.h = h;
    MQueue_SendToServer(s->raven,&packet,sizeof(RavenPacket));
}

RavenEvent* RavenGetEvent(RavenSession* s) {
    size_t size;
    RavenEvent* packet = MQueue_RecieveFromServer(s->raven,&size);
    if(size != sizeof(RavenEvent)) {
        free(packet);
        return NULL;
    }
    return packet;
}