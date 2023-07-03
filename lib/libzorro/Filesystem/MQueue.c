#include "MQueue.h"
#include "../Common/Alloc.h"

MQueue* MQueue_Bind(const char* path) {
    if(Create(path,0) != 0) {
        return NULL;
    }
    MQueue* mq = malloc(sizeof(MQueue));
    mq->isServer = true;
    if(Open(path,O_RDWR,&mq->file) < 0) {
        free(mq);
        return NULL;
    }
    return mq;
}

MQueue* MQueue_Connect(const char* path) {
    MQueue* mq = malloc(sizeof(MQueue));
    mq->isServer = false;
    if(Open(path,O_RDWR,&mq->file) < 0) {
        free(mq);
        return NULL;
    }
    return mq;
}