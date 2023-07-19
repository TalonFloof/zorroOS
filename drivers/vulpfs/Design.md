# VulpFS Design
## Superblock
The superblock is placeed within several different locations depending on the size of the filesystem in question.
These locations are (in bytes): 
```
    0x10000 (64 KiB), 0x4000000 (64 MiB), 0x80000000 (4 GiB), 0x4000000000 (256 GiB), 0x40000000000 (4 TiB)
```
### On-Disk structure
```c
typedef struct {
    uint8_t uuid[10];
    uint64_t ourLBA; // Differs for each superblock
    uint8_t magic[8]; // "VulpFSsb"

} VulpFSSuperBlock;
```
WIP!!!!!