# Fennec File System

## Layout
| OkamiBoot Metadata | Bootloader (optional) | Superblock | Journal (optional) | Inode Bitmap | Inodes | Zone Tag Table | Zones |
|--------------------|-----------------------|------------|--------------------|--------------|--------|----------------|-------|

## Superblock
```c
typedef enum {
    OKAY = 0xa072a572,
    ACTIVE = 0xbf0d34b6,
    DAMAGED = 0x5af5b64a,
} FennecFSState;

typedef struct {
    uint32_t icount; /* Inode Count */
    uint32_t journalsize; /* Journal Log Size (excludes metadata) */
    uint32_t ztagsize; /* Zone Tag Table Size (in Zones) */
    uint32_t zones; /* Number of zones */
    uint64_t zone; /* First block in zone */
    uint32_t zonesize; /* Zone Size (must be at least 1024) */
    FennecFSState state; /* Filesystem State */
    uint64_t magic; /* "\x80Fennec\x80" */
    uint32_t revision; /* 1 */
} FennecSuperblock;
```

## Zone Tag
```
0x00000000: Free Zone
0x00000001-0xfffffffd: Used Zone (points to next zone, this forms a linked chain)
0xfffffffe: Bad Zone (Damaged Block(s) contained within the zone)
0xffffffff: End of Zone Chain
```

## Inode
```c
typedef struct {
    uint32_t mode; /* Inode Type and Permission Bits */
    uint32_t links; /* Number of Hard Links */
    uint32_t uid; /* User ID */
    uint32_t gid; /* Group ID */
    uint64_t size; /* Data Size */
    int64_t atime; /* Access Time */
    int64_t mtime; /* Modify Time */
    int64_t ctime; /* Status Change Time */
    uint32_t firstzone; /* First Allocated Zone of the File */
    uint8_t reserved[72]; /* Reserved for future metadata */
    uint32_t iconcolor; /* Color of the inode icon */
    uint8_t icon[128]; /* 32x32 pixel 1-bit icon bitmap */
} FennecInode;
```

## Directory Entry
```c
typedef struct {
    uint32_t inodeid;
    char name[60];
} FennecDirEntry;
```