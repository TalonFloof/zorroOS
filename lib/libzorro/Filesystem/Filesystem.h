#ifndef _LIBZORRO_FILESYSTEM_FILESYSTEM_H
#define _LIBZORRO_FILESYSTEM_FILESYSTEM_H
#include "../System/Syscall.h"
#include <stdint.h>
#include <stddef.h>
typedef intptr_t off_t;
typedef int64_t off64_t;

#define O_ACCMODE 0x0007
#define O_EXEC 1
#define O_RDONLY 2
#define O_RDWR 3
#define O_SEARCH 4
#define O_WRONLY 5
#define O_APPEND 0x0008
#define O_CREAT 0x0010
#define O_DIRECTORY 0x0020
#define O_EXCL 0x0040
#define O_NOCTTY 0x0080
#define O_NOFOLLOW 0x0100
#define O_TRUNC 0x0200
#define O_NONBLOCK 0x0400
#define O_DSYNC 0x0800
#define O_RSYNC 0x1000
#define O_SYNC 0x2000
#define O_CLOEXEC 0x4000
#define O_PATH 0x8000

#define SEEK_CUR 1
#define SEEK_END 2
#define SEEK_SET 3

typedef struct {
    int64_t inodeID;
    int32_t mode;
    unsigned char nameLen;
    char name[256];
} DirEntry;

typedef struct {
    int64_t fd;
    void (*Close)(void* file);
    size_t (*Read)(void* file, void* addr, size_t size);
    size_t (*ReadDir)(void* file, off_t offset, void* addr);
    size_t (*Write)(void* file, void* addr, size_t size);
    off_t (*LSeek)(void* file, off_t offset, int whence);
    size_t (*Truncate)(void* file, size_t size);
    int64_t (*IOCtl)(void* file, int req, void* val);
} OpenedFile;

int64_t Open(const char* path, int mode, OpenedFile* file);
int64_t Create(const char* path, int mode);
int64_t ChDir(const char* path);

#endif