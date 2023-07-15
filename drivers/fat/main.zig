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
    fileAllocationTable: []u8,
    fatType: usize,
    chainTerminate: usize,
    rootDirectory: ?[]FATDirectoryEntry,
};

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
    //vol.fileAllocationTable = @as([*]u8, @alignCast(@ptrCast(DriverInfo.krnlDispatch.?.pagedAllocAnon(sectorsPerFAT * 512))))[0 .. sectorsPerFAT * 512];
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
