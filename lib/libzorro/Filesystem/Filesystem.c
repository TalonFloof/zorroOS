#include "Filesystem.h"

static void CloseInternal(void* file) {
    Syscall(0x10002,((OpenedFile*)file)->fd,0,0,0,0,0);
}

static size_t ReadInternal(void* file, void* addr, size_t len) {
    return (size_t)Syscall(0x10003,(uintptr_t)(((OpenedFile*)file)->fd),(uintptr_t)addr,len,0,0,0);
}

static size_t ReadDirInternal(void* file, off_t offset, void* addr) {
    return (size_t)Syscall(0x10004,(uintptr_t)(((OpenedFile*)file)->fd),offset,(uintptr_t)addr,0,0,0);
}

static size_t WriteInternal(void* file, void* addr, size_t len) {
    return (size_t)Syscall(0x10005,(uintptr_t)(((OpenedFile*)file)->fd),(uintptr_t)addr,len,0,0,0);
}

static off_t LSeekInternal(void* file, off_t offset, int whence) {
    return (off_t)Syscall(0x10006,(uintptr_t)(((OpenedFile*)file)->fd),offset,whence,0,0,0);
}

static size_t TruncateInternal(void* file, size_t size) {
    return (size_t)Syscall(0x10007,(uintptr_t)(((OpenedFile*)file)->fd),size,0,0,0,0);
}

static int64_t IOCtlInternal(void* file, int req, void* arg) {
    return (int64_t)Syscall(0x10010,(uintptr_t)(((OpenedFile*)file)->fd),req,(uintptr_t)arg,0,0,0);
}

int64_t Open(const char* path, int mode, OpenedFile* file) {
    int64_t ret = (int64_t)Syscall(0x10001,(uintptr_t)path,mode,0,0,0,0);
    if(ret >= 0 && file != NULL) {
        file->fd = ret;
        file->Close = CloseInternal;
        file->Read = ReadInternal;
        file->ReadDir = ReadDirInternal;
        file->Write = WriteInternal;
        file->LSeek = LSeekInternal;
        file->Truncate = TruncateInternal;
        file->IOCtl = IOCtlInternal;
    }
    return ret;
}

int64_t Create(const char* path, int mode) {
    return (int64_t)Syscall(0x10008,(uintptr_t)path,mode,0,0,0,0);
}

int64_t ChDir(const char* path) {
    return (int64_t)Syscall(0x10013,(uintptr_t)path,0,0,0,0,0);
}