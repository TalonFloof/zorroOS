/*
Copyright (C) 2023 TalonFox

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <math.h>
#include <stdlib.h>
#include <time.h>
#include <stdbool.h>

const uint8_t DefaultFileIcon[] = {
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x18, 0x00, 0x00, 0x00, 0x3e, 0x00, 0x00,
  0x00, 0x7f, 0x80, 0x00, 0x00, 0xf5, 0xe0, 0x00, 0x01, 0xea, 0x78, 0x00,
  0x03, 0xd4, 0x9e, 0x00, 0x07, 0xa8, 0x07, 0x80, 0x0f, 0x52, 0x81, 0xe0,
  0x1e, 0xa0, 0x00, 0x78, 0x3d, 0x4a, 0x00, 0x1c, 0x7a, 0x80, 0x00, 0x18,
  0xf5, 0x28, 0x00, 0x30, 0x7a, 0x00, 0x00, 0x68, 0x1e, 0xa5, 0x54, 0xc4,
  0x07, 0x80, 0x01, 0x82, 0x01, 0xe5, 0x57, 0x06, 0x03, 0x78, 0xae, 0x18,
  0x01, 0xbf, 0x5c, 0x60, 0x00, 0xd7, 0xf9, 0x80, 0x00, 0x6b, 0xfe, 0x00,
  0x00, 0x35, 0x60, 0x00, 0x00, 0x1b, 0x80, 0x00, 0x00, 0x06, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
};

const uint8_t DefaultDirectoryIcon[] = {
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x01, 0x8f, 0x81, 0xf0, 0x01, 0xff, 0xff, 0xfe,
  0xc1, 0x3f, 0xff, 0xfe, 0xf9, 0x07, 0xff, 0xfc, 0x47, 0x00, 0xff, 0xfc,
  0x59, 0x00, 0x1f, 0xfc, 0x6e, 0xe0, 0x03, 0xfc, 0x2f, 0x3c, 0x00, 0xf8,
  0x2f, 0xcf, 0x00, 0xf8, 0x17, 0xf1, 0xe0, 0xf0, 0x17, 0xfe, 0x31, 0xf0,
  0x17, 0xff, 0xc9, 0xf0, 0x0b, 0xff, 0xe9, 0xe0, 0x0b, 0xff, 0xe9, 0xe0,
  0x0b, 0xff, 0xe9, 0xc0, 0x05, 0xff, 0xeb, 0xc0, 0x04, 0xff, 0xeb, 0xc0,
  0x03, 0x3f, 0xeb, 0x80, 0x01, 0xdf, 0xeb, 0x80, 0x00, 0x67, 0xeb, 0x00,
  0x00, 0x3b, 0xeb, 0x00, 0x00, 0x0c, 0xea, 0x00, 0x00, 0x03, 0x2a, 0x00,
  0x00, 0x00, 0xca, 0x00, 0x00, 0x00, 0x6c, 0x00, 0x00, 0x00, 0x1c, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
};

typedef enum {
    OKAY = 0xa072a572,
    ACTIVE = 0xbf0d34b6,
    DAMAGED = 0x5af5b64a,
} FennecFSState;

typedef struct {
    uint32_t icount; /* Inode Count 0x0 */
    uint32_t firstinode; /* First block in Inodes 0x4 */
    uint32_t ztagsize; /* Zone Tag Table Size (in Zones) 0x8 */
    uint32_t zones; /* Number of zones  0xc */
    uint64_t zone; /* First block in zone 0x10 */
    uint32_t zonesize; /* Zone Size (must be at least 1024) 0x18 */
    uint32_t journalsize; /* Journal Log Size (excludes metadata) 0x1c */
    uint64_t ztt; /* First block in ZZT 0x20 */
    FennecFSState state; /* Filesystem State 0x28 */
    uint32_t revision; /* 1 0x2c */
    uint64_t magic; /* "\x80Fennec\x80" */
} FennecSuperblock;

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

typedef struct {
    uint32_t inodeid;
    char name[60];
} FennecDirEntry;

uint8_t* readImage(const char* path, size_t* imgSize) {
    FILE* file = fopen(path,"rb");
    if(file == NULL)
        return NULL;
    fseek(file, 0, SEEK_END);
    long fsize = ftell(file);
    if(imgSize != NULL) {
        *imgSize = fsize;
    }
    fseek(file, 0, SEEK_SET);
    uint8_t* content = malloc(fsize);
    if(fread(content, fsize, 1, file) != 1)
        return NULL;
    fclose(file);
    return content;
}

uint8_t* readImageAndValidate(const char* path, size_t* imgSize, uint64_t offset) {
    uint8_t* img = readImage(path,imgSize);
    FennecSuperblock* super = (FennecSuperblock*)(img+offset);
    if(super->magic != 0x8063656E6E654680) {
        fprintf(stderr, "Invalid magic\n");
        free(img);
        exit(2);
    }
    return img;
}

void writeImage(const char* path, uint8_t* base, size_t len) {
    FILE* file = fopen(path,"wb");
    if(file == NULL) {
        fprintf(stderr, "Couldn't open file for image writing!\n");
        fclose(file);
        exit(1);
    }
    if(fwrite(base,len,1,file) != 1) {
        fprintf(stderr, "Failed to write to file!\n");
        fclose(file);
        exit(1);
    }
    fclose(file);
}

uint64_t ibmSize(FennecSuperblock* super) {
    return ((uint64_t)ceil(((double)super->icount)/4096.0))*512;
}

uint32_t* getZoneTag(FennecSuperblock* super, uint32_t index) {
    uint64_t zttStart = super->zone-(super->ztagsize*(super->zonesize/512));
    return (uint32_t*)(((uintptr_t)super)+(zttStart*512)+(index*4));
}

uint32_t getFreeZone(FennecSuperblock* super) {
    for(int i=0; i < super->zones; i++) {
        if((*getZoneTag(super,i)) == 0) {
            return i;
        }
    }
    return 0xffffffff;
}

FennecInode* getInode(FennecSuperblock* super, uint32_t inode) {
    return (FennecInode*)(((uintptr_t)super)+512+ibmSize(super)+((inode-1)*sizeof(FennecInode)));
}

void setBitmapEntry(FennecSuperblock* super, uint32_t index, bool val) {
    uint8_t* v = (((uint8_t*)super)+512+((index-1)/8));
    v[0] &= ~(1 << ((index-1) & 7));
    v[0] |= (((uint8_t)val) << ((index-1) & 7));
}

bool getBitmapEntry(FennecSuperblock* super, uint32_t index) {
    uint8_t* v = (((uint8_t*)super)+512+((index-1)/8));
    return (v[0] & (1 << ((index-1) & 7))) != 0;
}

uint32_t getFreeInode(FennecSuperblock* super) {
    for(int i=0;i < super->icount; i++) {
        if(!getBitmapEntry(super,i+1)) {
            return i+1;
        }
    }
    return 0;
}

uint8_t* readInode(FennecSuperblock* super, FennecInode* inode) {
    uint64_t size = inode->size;
    if(size == 0) {
        return NULL;
    }
    uint8_t* data = malloc(size);
    uint32_t i = 0;
    uint32_t entry = inode->firstzone;
    uint8_t* zoneBegin = ((uint8_t*)super)+(super->zone*512);
    while(entry != 0xfffffffe) {
        memcpy(&data[i],zoneBegin+(entry*super->zonesize),((size>(super->zonesize))?(super->zonesize):size));
        i += ((size>(super->zonesize))?(super->zonesize):size);
        size -= ((size>(super->zonesize))?(super->zonesize):size);
        entry = (*getZoneTag(super,entry))-1;
    }
    return data;
}

void writeInode(FennecSuperblock* super, FennecInode* inode, uint8_t* data, uint64_t size) {
    /* First, delete the entire chain */
    inode->mtime = (int64_t)time(NULL);
    inode->size = size;
    if(inode->firstzone != 0xffffffff) {
        uint32_t* entry = getZoneTag(super,inode->firstzone);
        for(;;) {
            uint32_t val = *entry;
            *entry = 0;
            if(val == 0xFFFFFFFF) {
                break;
            }
            entry = getZoneTag(super,val-1);
        }
    }
    if(data == NULL || size == 0) {
        inode->firstzone = 0xffffffff;
        return;
    }
    uint32_t* prev = NULL;
    uint8_t* zoneBegin = ((uint8_t*)super)+(super->zone*512);
    uint32_t i = 0;
    uint32_t zone;
    while(size > super->zonesize) {
        zone = getFreeZone(super);
        *(getZoneTag(super,zone)) = 0xffffffff; /* Temporary */
        if(prev != NULL) {
            *prev = zone+1;
        } else {
            inode->firstzone = zone;
        }
        memcpy(zoneBegin+(zone*(super->zonesize)),data+i,super->zonesize);
        prev = getZoneTag(super,zone);
        size -= super->zonesize;
        i += super->zonesize;
    }
    zone = getFreeZone(super);
    if(prev != NULL) {
        *prev = zone+1;
    } else {
        inode->firstzone = zone;
    }
    *(getZoneTag(super,zone)) = 0xffffffff;
    memcpy(zoneBegin+(zone*super->zonesize),data+i,size);
}

uint32_t findFile(FennecSuperblock* super, char* path) {
    if(path == NULL || strcmp(path,"/") == 0 || strlen(path) == 0) {return 1;}
    char* token = strtok(path,"/");
    uint32_t inode = 1;
    while(token != NULL) {
        if(strlen(token) == 0) {goto foundentry;}
        FennecDirEntry* entries = (FennecDirEntry*)readInode(super,getInode(super,inode));
        if(entries == NULL) {return 0;}
        uint32_t entryCount = (getInode(super,inode)->size)/sizeof(FennecDirEntry);
        for(int i=0; i < entryCount; i++) {
            if(entries[i].inodeid != 0) {
                if(strcmp(token,(char*)(&(entries[i].name))) == 0) {
                    inode = entries[i].inodeid;
                    free(entries);
                    goto foundentry;
                }
            }
        }
        free(entries);
        return 0;
foundentry:
        token = strtok(NULL,"/");
    }
    return inode;
}

uint32_t findParent(FennecSuperblock* super, char* path, char** fileName) {
    int fileNameBegin = strlen(path);
    while(path[fileNameBegin] != '/') {fileNameBegin--;}
    fileNameBegin++;
    if(fileName != NULL) {
        *fileName = path+fileNameBegin;
    }
    int parentPathSize = ((fileNameBegin-1) < 0) ? 0 : (fileNameBegin-1);
    char* name = NULL;
    if(parentPathSize > 0) {
        name = malloc(parentPathSize+1);
        memset(name,0,parentPathSize+1);
        memcpy(name,path,parentPathSize);
    }
    uint32_t ret = findFile(super,name);
    free(name);
    return ret;
}

void addDirEntry(FennecSuperblock* super, FennecInode* dir, uint32_t id, char* name) {
    FennecDirEntry* entries = (FennecDirEntry*)readInode(super,dir);
    uint64_t entryCount = dir->size/sizeof(FennecDirEntry);
    for(int i=0; i < entryCount; i++) {
        if(entries[i].inodeid == 0) {
            entries[i].inodeid = id;
            memset((char*)&entries[entryCount].name,0,60);
            memcpy((char*)&entries[i].name,name,strlen(name)+1);
            writeInode(super,dir,(uint8_t*)entries,dir->size);
            free(entries);
            return;
        }
    }
    entries = realloc(entries,(entryCount+1)*sizeof(FennecDirEntry));
    entries[entryCount].inodeid = id;
    memset((char*)&entries[entryCount].name,0,60);
    memcpy((char*)&entries[entryCount].name,name,strlen(name)+1);
    writeInode(super,dir,(uint8_t*)entries,dir->size+sizeof(FennecDirEntry));
    free(entries);
}

uint8_t* generateImage(uint64_t kib, uint64_t begin, uint64_t zonesize, uint64_t ratio) {
    uint64_t size = kib*1024;
    uint8_t* dat = malloc(size);
    memset(dat,0,size);
    uint32_t inodes = 0;
    if(ratio == 0) {
        if(kib >= 4194304) {
            inodes = size/65536;
        } else if(kib > 1048576) {
            inodes = size/32768;
        } else {
            inodes = size/16384;
        }
    } else {
        inodes = size/ratio;
    }
    uint32_t ibm = ceil(((double)inodes)/4096.0);
    uint32_t zones = (size-(ibm*512)-(begin-512)-(inodes*256))/zonesize;
    uint32_t ztt = ceil((double)(zones*4)/(double)zonesize);
    printf("mkfs.fennecfs %i Inodes (%i block(s) for Bitmap), %i Zones (Extra %i zones are reserved for the Zone Tag Table)\n", inodes, ibm, zones-ztt, ztt);
    FennecSuperblock* super = (FennecSuperblock*)(dat+begin);
    super->magic = 0x8063656E6E654680;
    super->revision = 1;
    super->state = OKAY;
    super->icount = inodes;
    super->firstinode = 1+ibm;
    super->journalsize = 0; /* To be implemented... */
    super->zonesize = zonesize;
    super->zones = zones-ztt;
    super->zone = 1+ibm+(inodes/2)+(ztt*(zonesize/512));
    super->ztagsize = ztt;
    super->ztt = 1+ibm+(inodes/2);
    FennecInode* root = getInode(super,1);
    root->mode = 0040755; /* drwxr-xr-x */
    root->links = 1;
    root->uid = 0;
    root->gid = 0;
    root->size = 0;
    root->atime = (int64_t)time(NULL);
    root->mtime = root->atime;
    root->ctime = root->atime;
    root->iconcolor = 0; /* Use default Icon */
    root->size = 0;
    root->firstzone = 0xffffffff;
    setBitmapEntry(super,1,true);
    return dat;
}

int main(int argc, char** argv) {
    if(argc < 4) {
        printf("FennecFSTool: The swiss-army knife of FennecFS\nCopyright (C) 2023 TalonFox, Licensed Under the MIT License. (see source code for more information)\n");
        printf("Usage: fennecfstool [img [offset [command] ...]]\n");
        printf("Commands:\n");
        printf("newimage [KiB] [zonesize] [inoderatio]\n");
        printf("bootldr [bootimg]\n");
        printf("copy [src] [dst]\n");
        printf("mkdir [path]\n");
        printf("ls [path]\n");
        printf("cat [path]\n");
        printf("delete [path]\n");
        printf("chmod [path] [mode]\n");
        printf("chown [path] [user] [group]\n");
        printf("seticon [path] [color (Specify \"current\" to retain the current color)] -\n");
        printf("geticon [path]\n");
        return 1;
    } else {
        uint64_t startOffset = strtoull(argv[2],NULL,0)*512;
        size_t fileSize;
        if(strcmp(argv[3],"newimage") == 0) {
            uint64_t kib = strtoull(argv[4],NULL,0);
            uint64_t inoderatio = 0;
            uint64_t zonesize = 1024;
            if(argc >= 6) {
                zonesize = strtoull(argv[5],NULL,0);
            }
            if(argc >= 7) {
                inoderatio = strtoull(argv[6],NULL,0);
            }
            uint8_t* data = generateImage(kib,startOffset,zonesize,inoderatio);
            writeImage(argv[1],data,kib*1024);
            free(data);
        } else {
            if(strcmp(argv[3],"bootldr") == 0) {
                uint8_t* data = readImageAndValidate(argv[1],&fileSize,startOffset);
                size_t bootldrSize;
                uint8_t* boot = readImage(argv[4],&bootldrSize);
                fprintf(stderr, "%i\n", bootldrSize);
                memcpy(data,boot,bootldrSize);
                free(boot);
                writeImage(argv[1],data,fileSize);
                free(data);
            } else if(strcmp(argv[3],"copy") == 0) {
                uint8_t* data = readImageAndValidate(argv[1],&fileSize,startOffset);
                FennecSuperblock* super = (FennecSuperblock*)(data+startOffset);
                char* dirName;
                uint32_t parentInode = findParent(super,argv[5],&dirName);
                if(parentInode == 0) {
                    fprintf(stderr,"Unable to retrieve parent Inode\n");
                    free(data);
                    exit(3);
                }
                uint32_t newInode = getFreeInode(super);
                if(newInode == 0) {
                    fprintf(stderr,"Out of Inodes!\n");
                    free(data);
                    exit(3);
                }
                setBitmapEntry(super,newInode,1);
                FennecInode* inode = getInode(super,newInode);
                inode->mode = 0100644;
                inode->links = 1;
                inode->uid = 0;
                inode->gid = 0;
                inode->atime = (int64_t)time(NULL);
                inode->mtime = inode->atime;
                inode->ctime = inode->atime;
                inode->iconcolor = 0;
                inode->firstzone = 0xffffffff;
                inode->size = 0;
                addDirEntry(super,getInode(super,parentInode),newInode,dirName);
                size_t srcSize;
                uint8_t* img = readImage(argv[4],&srcSize);
                writeInode(super,inode,img,srcSize);
                free(img);
                writeImage(argv[1],data,fileSize);
                free(data);
            } else if(strcmp(argv[3],"mkdir") == 0) {
                uint8_t* data = readImageAndValidate(argv[1],&fileSize,startOffset);
                FennecSuperblock* super = (FennecSuperblock*)(data+startOffset);
                char* dirName;
                uint32_t parentInode = findParent(super,argv[4],&dirName);
                if(parentInode == 0) {
                    fprintf(stderr,"Unable to retrieve parent Inode\n");
                    free(data);
                    exit(3);
                }
                uint32_t newInode = getFreeInode(super);
                if(newInode == 0) {
                    fprintf(stderr,"Out of Inodes!\n");
                    free(data);
                    exit(3);
                }
                setBitmapEntry(super,newInode,1);
                FennecInode* inode = getInode(super,newInode);
                inode->mode = 0040755;
                inode->links = 1;
                inode->uid = 0;
                inode->gid = 0;
                inode->atime = (int64_t)time(NULL);
                inode->mtime = inode->atime;
                inode->ctime = inode->atime;
                inode->iconcolor = 0;
                inode->firstzone = 0xffffffff;
                inode->size = 0;
                addDirEntry(super,getInode(super,parentInode),newInode,dirName);
                writeImage(argv[1],data,fileSize);
                free(data);
            } else if(strcmp(argv[3],"ls") == 0) {
                uint8_t* data = readImageAndValidate(argv[1],NULL,startOffset);
                FennecSuperblock* super = (FennecSuperblock*)(data+startOffset);
                uint32_t inode = findFile(super,argv[4]);
                if(inode == 0) {
                    fprintf(stderr,"Unable to retrieve Inode\n");
                    free(data);
                    exit(3);
                }
                FennecDirEntry* entries = (FennecDirEntry*)readInode(super,getInode(super,inode));
                uint32_t entryCount = getInode(super,inode)->size/sizeof(FennecDirEntry);
                for(int i=0; i < entryCount; i++) {
                    if(entries[i].inodeid != 0) {
                        FennecInode* ino = getInode(super,entries[i].inodeid);
                        struct tm* mTime = localtime((const time_t*)&(ino->mtime));
                        char buffer[80];
                        strftime((char*)&buffer,80,"%b %e %R",mTime);
                        printf("%06o %i %5i %5i %16lli %s %s\n",ino->mode,ino->links,ino->uid,ino->gid,ino->size,(char*)buffer,entries[i].name);
                    }
                }
                free(entries);
                free(data);
            } else if(strcmp(argv[3],"cat") == 0) {
                uint8_t* data = readImageAndValidate(argv[1],&fileSize,startOffset);
                FennecSuperblock* super = (FennecSuperblock*)(data+startOffset);
                uint32_t inode = findFile(super,argv[4]);
                if(inode == 0) {
                    fprintf(stderr,"Unable to retrieve Inode\n");
                    free(data);
                    exit(3);
                }
                uint8_t* img = readInode(super,getInode(super,inode));
                fwrite(img,getInode(super,inode)->size,1,stdout);
                free(img);
                free(data);
            } else if(strcmp(argv[3],"delete") == 0) {
                uint8_t* data = readImageAndValidate(argv[1],&fileSize,startOffset);
                FennecSuperblock* super = (FennecSuperblock*)(data+startOffset);
                char* name;
                uint32_t parent = findParent(super,argv[4],&name);
                FennecDirEntry* entries = (FennecDirEntry*)readInode(super,getInode(super,parent));
                uint32_t entryCount = getInode(super,parent)->size/sizeof(FennecDirEntry);
                for(int i=0; i < entryCount; i++) {
                    if(entries[i].inodeid != 0 && strcmp(name,entries[i].name) == 0) {
                        FennecInode* inode = getInode(super,entries[i].inodeid);
                        if((inode->mode & 0170000) == 0040000 && inode->size > 0) {
                            fprintf(stderr, "Directory is not empty\n");
                            free(entries);
                            free(data);
                            exit(4);
                        }
                        writeInode(super,inode,NULL,0);
                        setBitmapEntry(super,entries[i].inodeid,false);
                        entries[i].inodeid = 0;
                        writeInode(super,getInode(super,parent),(uint8_t*)entries,entryCount*sizeof(FennecDirEntry));
                        writeImage(argv[1],data,fileSize);
                        free(entries);
                        free(data);
                        exit(0);
                    }
                }
                fprintf(stderr, "File not found\n");
                free(entries);
                free(data);
                return 0;
            } else if(strcmp(argv[3],"chmod") == 0) {
                uint8_t* data = readImageAndValidate(argv[1],&fileSize,startOffset);
                FennecSuperblock* super = (FennecSuperblock*)(data+startOffset);
                uint32_t inode = findFile(super,argv[4]);
                if(inode == 0) {
                    fprintf(stderr,"Unable to retrieve Inode\n");
                    free(data);
                    exit(3);
                }
                uint32_t perm = strtoul(argv[5],NULL,8);
                getInode(super,inode)->mode = ((getInode(super,inode)->mode) & 0170000) | (perm & 07777);
                writeImage(argv[1],data,fileSize);
                free(data);
            } else if(strcmp(argv[3],"chown") == 0) {
                uint8_t* data = readImageAndValidate(argv[1],&fileSize,startOffset);
                FennecSuperblock* super = (FennecSuperblock*)(data+startOffset);
                uint32_t inode = findFile(super,argv[4]);
                if(inode == 0) {
                    fprintf(stderr,"Unable to retrieve Inode\n");
                    free(data);
                    exit(3);
                }
                uint32_t uid = strtoul(argv[5],NULL,10);
                uint32_t gid = strtoul(argv[6],NULL,10);
                getInode(super,inode)->uid = uid;
                getInode(super,inode)->gid = gid;
                writeImage(argv[1],data,fileSize);
                free(data);
            } else if(strcmp(argv[3],"seticon") == 0) {
                uint8_t* data = readImageAndValidate(argv[1],&fileSize,startOffset);
                FennecSuperblock* super = (FennecSuperblock*)(data+startOffset);
                uint32_t inode = findFile(super,argv[4]);
                if(inode == 0) {
                    fprintf(stderr,"Unable to retrieve Inode\n");
                    free(data);
                    exit(3);
                }
                if(strcmp(argv[5],"current") != 0) {
                    getInode(super,inode)->iconcolor = strtoull(argv[5],NULL,0);
                }
                if(argc > 5 && strcmp(argv[6],"-") == 0) {
                    fread((uint8_t*)(&(getInode(super,inode)->icon)),128,1,stdin);
                }
                writeImage(argv[1],data,fileSize);
                free(data);
            } else if(strcmp(argv[3],"geticon") == 0) {
                uint8_t* data = readImageAndValidate(argv[1],&fileSize,startOffset);
                FennecSuperblock* super = (FennecSuperblock*)(data+startOffset);
                uint32_t inode = findFile(super,argv[4]);
                if(inode == 0) {
                    fprintf(stderr,"Unable to retrieve Inode\n");
                    free(data);
                    exit(3);
                }
                fwrite((uint8_t*)(&(getInode(super,inode)->icon)),128,1,stdout);
                free(data);
            }
        }
    }
    return 0;
}