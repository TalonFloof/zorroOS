const devlib = @import("devlib");
const std = @import("std");

pub export var DriverInfo = devlib.RyuDriverInfo{
    .apiMinor = 1,
    .apiMajor = 0,
    .drvName = "FATFilesystem",
    .exportedDispatch = null,
    .loadFn = &LoadDriver,
    .unloadFn = &UnloadDriver,
};

////////////// FAT STRUCTURES

const Superblock16 = extern struct {
    jmp: [3]u8 align(1),
    oemName: [8]u8 align(1),
    bytesPerSector: u16 align(1),
    sectorsPerCluster: u8 align(1),
    reservedSectors: u16 align(1),
    fatCount: u8 align(1),
    rootDirectoryEntries: u16 align(1),
    totalSectors: u16 align(1),
    mediaDescriptor: u8 align(1),
    sectorsPerFAT16: u16 align(1),
    sectorsPerTrack: u16 align(1),
    heads: u16 align(1),
    hiddenSectors: u32 align(1),
    largeSectorCount: u32 align(1),

    deviceID: u8 align(1),
    flags: u8 align(1),
    signature: u8 align(1),
    serial: u32 align(1),
    label: [11]u8 align(1),
    systemIdentifier: u64 align(1),
    unused: [450]u8 align(1),
};

const Superblock32 = extern struct {
    jmp: [3]u8 align(1),
    oemName: [8]u8 align(1),
    bytesPerSector: u16 align(1),
    sectorsPerCluster: u8 align(1),
    reservedSectors: u16 align(1),
    fatCount: u8 align(1),
    rootDirectoryEntries: u16 align(1),
    totalSectors: u16 align(1),
    mediaDescriptor: u8 align(1),
    sectorsPerFAT16: u16 align(1),
    sectorsPerTrack: u16 align(1),
    heads: u16 align(1),
    hiddenSectors: u32 align(1),
    largeSectorCount: u32 align(1),

    sectorsPerFAT32: u32 align(1),
    flags: u16 align(1),
    version: u16 align(1),
    rootDirectoryCluster: u32 align(1),
    fsInfoSector: u16 align(1),
    backupBootSector: u16 align(1),
    unused1: [12]u8 align(1),
    deviceID: u8 align(1),
    flags2: u8 align(1),
    signature: u8 align(1),
    serial: u32 align(1),
    label: [11]u8 align(1),
    systemIdentifier: u64 align(1),
    unused2: [422]u8 align(1),
};

const Superblock = extern union {
    superBlk16: Superblock16,
    superBlk32: Superblock32,
};

const FATDirectoryEntry = extern struct {
    name: [11]u8 align(1),
    attributes: u8 align(1),
    reserved: u8 align(1),
    creationTimeSeconds: u8 align(1),
    creationTime: u16 align(1),
    creationDate: u16 align(1),
    accessedDate: u16 align(1),
    firstClusterHigh: u16 align(1),
    modificationTime: u16 align(1),
    modificationDate: u16 align(1),
    firstClusterLow: u16 align(1),
    fileSizeBytes: u32 align(1),
};

/////////////////////////////

const VOLUME_FAT12 = 12;
const VOLUME_FAT16 = 16;
const VOLUME_FAT32 = 32;

const Volume = struct {
    superblock: Superblock,
    fs: *devlib.fs.Filesystem,
    fileAllocationTable: []u8,
    fatType: usize,
    chainTerminate: usize,
    sectorOffset: usize,
    rootDirectory: ?[]FATDirectoryEntry,
};

const FileEntry = struct {
    vol: *Volume,
    firstCluster: u32,
};

pub fn NextCluster(vol: *Volume, cluster: u32) u32 {
    if (vol.fatType == 12) {
        var byte1 = vol.fileAllocationTable[cluster * 3 / 2 + 0];
        var byte2 = vol.fileAllocationTable[cluster * 3 / 2 + 1];
        var ret: u32 = 0;
        if ((cluster & 1) != 0) {
            ret = (@as(u32, @intCast(byte2)) << 4) + (@as(u32, @intCast(byte1)) >> 4);
        } else {
            ret = (@as(u32, @intCast(byte2)) << 8) + (@as(u32, @intCast(byte1)) >> 0);
        }
        return ret & 0xFFF;
    } else if (vol.fatType == 16) {
        return @intCast(@as([*]u16, @alignCast(@ptrCast(vol.fileAllocationTable.ptr)))[cluster]);
    } else if (vol.fatType == 32) {
        return @intCast(@as([*]u32, @alignCast(@ptrCast(vol.fileAllocationTable.ptr)))[cluster]);
    }
    @panic("Undefined FAT Type!");
}

pub fn ReadDir(inode: *devlib.fs.Inode, offset: usize, entry: *devlib.fs.DirEntry) callconv(.C) isize {
    const file: *FileEntry = @alignCast(@ptrCast(inode.private));
    const superblock: *Superblock16 = &file.vol.superblock.superBlk16;
    var buffer = @as([*]u8, @alignCast(@ptrCast(DriverInfo.krnlDispatch.?.pagedAllocAnon(@as(usize, @intCast(superblock.sectorsPerCluster)) * @as(usize, @intCast(superblock.bytesPerSector))))))[0..(@as(usize, @intCast(superblock.sectorsPerCluster)) * @as(usize, @intCast(superblock.bytesPerSector)))];
    defer DriverInfo.krnlDispatch.?.pagedFreeAnon(@ptrCast(buffer.ptr), buffer.len); // Honestly i forgot that zig can defer X3
    var currentCluster: u32 = file.firstCluster;
    var ind: usize = 0;
    while (currentCluster < file.vol.chainTerminate) {
        if (file.vol.fs.dev.?.read.?(file.vol.fs.dev.?, @intCast(file.vol.sectorOffset + (currentCluster * @as(u32, @intCast(superblock.sectorsPerCluster)))), @ptrCast(buffer.ptr), @intCast(superblock.sectorsPerCluster)) < superblock.sectorsPerCluster) {
            DriverInfo.krnlDispatch.?.abort("Failed to read cluster while preforming ReadDir!\n");
            return -5;
        }
        var i: usize = 0;
        while (i < ((@as(usize, superblock.sectorsPerCluster) * @as(usize, superblock.bytesPerSector)) / @sizeOf(FATDirectoryEntry))) : (i += 1) {
            const ent = @as(*FATDirectoryEntry, @ptrCast(@alignCast(&buffer[i * @sizeOf(FATDirectoryEntry)])));
            if (ent.name[0] == 0xe5 or ent.attributes == 0x0f or (ent.attributes & 8) != 0) {
                continue;
            }
            if (ent.name[0] == 0) {
                return 0;
            }
            if (ent.name[0] == '.' and (ent.name[1] == '.' or ent.name[1] == ' ') and ent.name[2] == ' ') {
                continue;
            }
            if (ind == offset) {
                const hasExt = ent.name[8] != ' ' or ent.name[9] != ' ' or ent.name[10] != ' ';
                var name: [13]u8 = [_]u8{0} ** 13;
                var nameLen: usize = 0;
                var j: usize = 0;
                while (j < 11) : (j += 1) {
                    if (j == 8 and hasExt) {
                        name[nameLen] = '.';
                        nameLen += 1;
                    }
                    if (ent.name[j] != ' ') {
                        name[nameLen] = ent.name[j];
                        nameLen += 1;
                    }
                }
                std.mem.copyForwards(u8, @as([*]u8, @ptrCast(&entry.name))[0 .. nameLen + 1], name[0 .. nameLen + 1]);
                entry.nameLen = @intCast(nameLen);
                entry.inodeID = 0xffffffff;
                entry.mode = if ((ent.attributes & 0x10) != 0) 0o0040775 else 0o0000775;
                return @intCast((@sizeOf(devlib.fs.DirEntry) - @sizeOf([256]u8)) + entry.nameLen);
            } else {
                ind += 1;
            }
        }
        currentCluster = NextCluster(file.vol, currentCluster);
    }
    return 0;
}

pub fn Mount(fs: *devlib.fs.Filesystem) callconv(.C) bool {
    if (fs.dev == null) {
        DriverInfo.krnlDispatch.?.put("Partition was null!\n");
        return false;
    }
    const vol = @as(*Volume, @ptrCast(@alignCast(DriverInfo.krnlDispatch.?.pagedAlloc(@sizeOf(Volume)))));
    const num = fs.dev.?.read.?(fs.dev.?, 0, @ptrCast(&vol.superblock), 1);
    if (num < 1) {
        DriverInfo.krnlDispatch.?.put("Failed to read from partition!\n");
        DriverInfo.krnlDispatch.?.pagedFree(@ptrCast(vol), @sizeOf(Volume));
        return false;
    }
    const sectorCount = if (vol.superblock.superBlk16.totalSectors != 0) vol.superblock.superBlk16.totalSectors else vol.superblock.superBlk16.largeSectorCount;
    const clusterCount = sectorCount / vol.superblock.superBlk16.sectorsPerCluster;
    var sectorsPerFAT: usize = 0;
    if (clusterCount < 0xff5) {
        vol.fatType = VOLUME_FAT12;
        vol.chainTerminate = 0xff8;
        sectorsPerFAT = vol.superblock.superBlk32.sectorsPerFAT16;
        DriverInfo.krnlDispatch.?.put("Found a FAT12 filesystem!\n");
    } else if (clusterCount < 0xfff5) {
        vol.fatType = VOLUME_FAT16;
        vol.chainTerminate = 0xfff8;
        sectorsPerFAT = vol.superblock.superBlk32.sectorsPerFAT16;
        DriverInfo.krnlDispatch.?.put("Found a FAT16 filesystem!\n");
    } else if (clusterCount < 0x0ffffff5) {
        vol.fatType = VOLUME_FAT32;
        vol.chainTerminate = 0x0ffffff8;
        sectorsPerFAT = vol.superblock.superBlk32.sectorsPerFAT32;
        DriverInfo.krnlDispatch.?.put("Found a FAT32 filesystem!\n");
    } else {
        DriverInfo.krnlDispatch.?.put("Cluster Count is unsupported! (prohaps this is an exFAT filesystem?)\n");
        DriverInfo.krnlDispatch.?.pagedFree(@ptrCast(vol), @sizeOf(Volume));
        return false;
    }
    vol.fs = fs;
    vol.fileAllocationTable = @as([*]u8, @alignCast(@ptrCast(DriverInfo.krnlDispatch.?.pagedAllocAnon(sectorsPerFAT * 512))))[0 .. sectorsPerFAT * 512];
    _ = fs.dev.?.read.?(fs.dev.?, vol.superblock.superBlk16.reservedSectors, @ptrCast(vol.fileAllocationTable.ptr), @intCast(sectorsPerFAT));
    var rootDirectoryOffset: usize = @as(usize, vol.superblock.superBlk16.reservedSectors) + vol.superblock.superBlk16.fatCount * sectorsPerFAT;
    var rootDirectorySectors: usize = (@as(usize, vol.superblock.superBlk16.rootDirectoryEntries) * @sizeOf(FATDirectoryEntry) + (512 - 1)) / 512;
    vol.sectorOffset = rootDirectoryOffset + rootDirectorySectors - (2 * vol.superblock.superBlk16.sectorsPerCluster);
    var entry = @as(*FileEntry, @ptrCast(@alignCast(DriverInfo.krnlDispatch.?.pagedAlloc(@sizeOf(FileEntry)))));
    entry.vol = vol;
    entry.firstCluster = vol.superblock.superBlk32.rootDirectoryCluster;
    fs.root.mountPoint = fs;
    fs.root.private = @ptrCast(entry);
    fs.root.readdir = &ReadDir;
    return true;
}

pub fn UMount(fs: *devlib.fs.Filesystem) callconv(.C) void {
    _ = fs;
}

pub fn LoadDriver() callconv(.C) devlib.Status {
    if (DriverInfo.krnlDispatch) |dispatch| {
        dispatch.registerFilesystem("fat", &Mount, &UMount);
        return .Okay;
    }
    return .Failure;
}

pub fn UnloadDriver() callconv(.C) devlib.Status {
    return .Okay;
}

pub fn panic(msg: []const u8, stacktrace: ?*std.builtin.StackTrace, wat: ?usize) noreturn {
    _ = wat;
    _ = stacktrace;
    while (true) {
        DriverInfo.krnlDispatch.?.abort(@ptrCast(msg.ptr));
    }
}
