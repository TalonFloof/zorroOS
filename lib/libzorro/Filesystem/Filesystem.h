#ifndef _LIBZORRO_FILESYSTEM_FILESYSTEM_H
#define _LIBZORRO_FILESYSTEM_FILESYSTEM_H
#include "../System/Syscall.h"
#include <stdint.h>
#include <stddef.h>

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

typedef struct {
    int64_t inodeID;
    unsigned char nameLen;
    char name[256];
} DirEntry;

int64_t Open(const char* path, int mode);
SyscallCode Close(int64_t fd);
size_t Read(int64_t fd, void* base, size_t size);
size_t ReadDir(int64_t fd, intptr_t offset, void* base);
size_t Write(int64_t fd, void* base, size_t size);

#endif