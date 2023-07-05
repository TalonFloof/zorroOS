#include "MQueue.h"
#include "../Common/Alloc.h"
#include "../Common/String.h"

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

void MQueue_SendToServer(MQueue* mq, void* data, size_t size) {
    mq->file.Write(&mq->file,data,size);
}

void MQueue_SendToClient(MQueue* mq, int64_t id, void* data, size_t size) {
    uint8_t* buf = malloc(size+8);
    *((int64_t*)&buf[0]) = id;
    memcpy(&buf[8],data,size);
    mq->file.Write(&mq->file,buf,size+8);
    free(buf);
}

void* MQueue_RecieveFromClient(MQueue* mq, int64_t* id, size_t* size) {
    unsigned char buf[1024];
    size_t s = mq->file.Read(&mq->file,buf,1024);
    if(s < 0) {
        return NULL;
    } else if(size != NULL) {
        *size = s-8;
    }
    if(id != NULL) {
        *id = *((int64_t*)&buf);
    }
    unsigned char* out = malloc(s-8);
    memcpy(out,&buf[8],s-8);
    return (void*)out;
}

void* MQueue_RecieveFromServer(MQueue* mq, size_t* size) {
    unsigned char buf[1024];
    size_t s = mq->file.Read(&mq->file,buf,1024);
    if(s < 0) {
        return NULL;
    } else if(size != NULL) {
        *size = s;
    }
    unsigned char* out = malloc(s);
    memcpy(out,&buf,s);
    return (void*)out;
}

void MQueue_Close(MQueue* mq) {
    mq->file.Close(&mq->file);
    free(mq);
}