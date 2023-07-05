#ifndef _LIBZORRO_FILESYSTEM_MQUEUE_H
#define _LIBZORRO_FILESYSTEM_MQUEUE_H
#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>
#include "Filesystem.h"

typedef struct {
    OpenedFile file;
    bool isServer;
} MQueue;

MQueue* MQueue_Bind(const char* path);
MQueue* MQueue_Connect(const char* path);
void MQueue_SendToServer(MQueue* mq, void* data, size_t size);
void MQueue_SendToClient(MQueue* mq, int64_t id, void* data, size_t size);
void* MQueue_RecieveFromClient(MQueue* mq, int64_t* id, size_t* size);
void* MQueue_RecieveFromServer(MQueue* mq, size_t* size);
void MQueue_Close(MQueue* mq);

#endif