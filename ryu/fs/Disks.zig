const FS = @import("root").FS;
const std = @import("std");

const GPTHeader = extern struct {
    signature: u32 align(1),
    size: u32 align(1),
    crc32: u32 align(1),
    reserved: u32 align(1),
    currentLBA: u64 align(1),
    backupLBA: u64 align(1),
    firstLBA: u64 align(1),
    lastLBA: u64 align(1),
    diskGUID: [16]u8 align(1),
    partitionTableLBA: u64 align(1),
    partNum: u32 align(1),
    partEntrySize: u32 align(1),
    partEntriesCRC: u32 align(1),
};

const GPTEntry = extern struct {
    typeGUID: [16]u8 align(1),
    partitionGUID: [16]u8 align(1),
    startLBA: u64 align(1),
    endLBA: u64 align(1),
    flags: u64 align(1),
    name: [72]u8 align(1),
};

const Disk = struct {
    firstPartition: ?*Partition,
    read: *const fn (usize, *void, usize) callconv(.C) void,
    write: *const fn (usize, *void, usize) callconv(.C) void,

    pub fn Rescan() void {}
};

const Partition = struct {
    next: *Partition,
    owner: *Disk,
    startLBA: u64,
    endLBA: u64,
    id: usize,
};

pub fn ReadDisk(inode: *FS.Inode, offset: isize, bufBegin: *void, bufSize: isize) callconv(.C) void {
    _ = bufSize;
    _ = bufBegin;
    _ = offset;
    _ = inode;
}

pub fn RegisterDisk(
    name: []const u8,
    blocks: u64,
    read: *const fn (usize, *void, usize) callconv(.C) void,
    write: *const fn (usize, *void, usize) callconv(.C) void,
) void {
    _ = blocks;
    _ = write;
    _ = read;
    _ = name;
}
