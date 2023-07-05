#include "Raven.h"
#include <Common/Alloc.h>
#include <System/SharedMemory.h>

RavenSession* NewRavenSession() {
    RavenSession* s = malloc(sizeof(RavenSession));
    s->raven = MQueue_Connect("/dev/mqueue/Raven");
    return s;
}

ClientWindow* NewRavenWindow(RavenSession* s, int w, int h, int flags) {
    RavenPacket* packet = malloc(sizeof(RavenPacket));
    packet->type = RAVEN_CREATE_WINDOW;
    packet->create.w = w;
    packet->create.h = h;
    packet->create.flags = flags;
    MQueue_SendToServer(s->raven,packet,sizeof(RavenPacket));
    free(packet);
    RavenCreateWindowResponse* response = MQueue_RecieveFromServer(s->raven,NULL);
    ClientWindow* win = malloc(sizeof(ClientWindow));
    win->id = response->id;
    win->backID = response->backBuf;
    win->backBuf = MapSharedMemory(response->backBuf);
    win->w = w;
    win->h = h;
    free(response);
    return win;
}

