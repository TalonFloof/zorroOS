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

#endif