const FS = @import("root").FS;
const std = @import("std");
const Memory = @import("root").Memory;
const HAL = @import("root").HAL;
const Spinlock = @import("root").Spinlock;

const GPTHeader = extern struct {
    signature: u64 align(1),
    revision: u32 align(1),
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
    private: *allowzero void,
    inode: *FS.Inode,
    firstPartition: ?*Partition,
    read: *const fn (*allowzero void, usize, *void, usize) callconv(.C) void,
    write: *const fn (*allowzero void, usize, *void, usize) callconv(.C) void,

    pub fn Rescan(self: *Disk) void {
        while (self.firstPartition != null) {
            _ = self.firstPartition.?.inode.unlink.?(self.firstPartition.?.inode);
        }
        self.firstPartition = null;
        var buf: [512]u8 = [_]u8{0} ** 512;
        self.read(self.private, 1, @ptrCast(&buf), 512);
        var header: *GPTHeader = @alignCast(@ptrCast(&buf));
        if (header.signature == 0x5452415020494645) {
            if (header.partNum == 0) {
                return;
            }
            var partData = Memory.Pool.StaticPool.Alloc(if ((header.partNum * @sizeOf(GPTEntry)) % 512 != 0) ((header.partNum * @sizeOf(GPTEntry) / 512) + 1) * 512 else (header.partNum * @sizeOf(GPTEntry))).?;
            self.read(self.private, @intCast(header.partitionTableLBA), @ptrCast(partData.ptr), partData.len);
            var partitions: []GPTEntry = @as([*]GPTEntry, @alignCast(@ptrCast(partData.ptr)))[0..header.partNum];
            var i: usize = 0;
            while (i < partitions.len) : (i += 1) {
                if (!std.mem.eql(u8, partitions[i].typeGUID[0..16], ([_]u8{0} ** 16)[0..16])) {
                    var partition = @as(*Partition, @alignCast(@ptrCast(Memory.Pool.StaticPool.Alloc(@sizeOf(Partition)).?.ptr)));
                    partition.owner = self;
                    partition.id = i;
                    partition.startLBA = partition.startLBA;
                    partition.endLBA = partition.endLBA;
                    partition.next = self.firstPartition;
                    self.firstPartition = partition;
                    var inode = @as(*FS.Inode, @alignCast(@ptrCast(Memory.Pool.StaticPool.Alloc(@sizeOf(FS.Inode)).?.ptr)));
                    inode.private = @ptrCast(partition);
                    inode.isVirtual = true;
                    inode.read = &ReadPartition;
                    inode.write = &WritePartition;
                    inode.unlink = &UnlinkPartition;
                    inode.stat.uid = 1;
                    inode.stat.gid = 1;
                    inode.stat.ctime = HAL.Arch.GetCurrentTimestamp()[0];
                    inode.stat.mtime = inode.stat.ctime;
                    inode.stat.atime = inode.stat.ctime;
                    inode.stat.blksize = 512;
                    inode.stat.blocks = @intCast(partition.endLBA - partition.startLBA);
                    inode.stat.size = @intCast(partition.endLBA - partition.startLBA);
                    inode.stat.mode = 0o0060660;
                    inode.stat.nlinks = 1;
                    @memset(buf[0..512], 0);
                    @memcpy(buf[0..256], self.inode.name[0..256]);
                    const len = std.mem.len(@as([*c]u8, @ptrCast(&buf)));
                    _ = std.fmt.bufPrintZ((buf[0..256])[len..256], "p{}", .{i}) catch {
                        @panic("Couldn't format the partition number!");
                    };
                    FS.DevFS.RegisterDevice(buf[0..std.mem.len(@as([*c]u8, @ptrCast(&buf)))], inode);
                    HAL.Console.Put("Partition {s}: StartLBA=0x{x} EndLBA=0x{x}\n", .{ buf[0..std.mem.len(@as([*c]u8, @ptrCast(&buf)))], partitions[i].startLBA, partitions[i].endLBA });
                }
            }
            Memory.Pool.StaticPool.Free(partData);
        }
    }
};

const Partition = struct {
    next: ?*Partition,
    owner: *Disk,
    inode: *FS.Inode,
    startLBA: u64,
    endLBA: u64,
    id: usize,
};

pub fn ReadDisk(inode: *FS.Inode, offset: isize, bufBegin: *void, bufSize: isize) callconv(.C) isize {
    const private: *Disk = @alignCast(@ptrCast(inode.private));
    private.read(private.private, @intCast(offset), bufBegin, @intCast(bufSize * inode.stat.blksize));
    return bufSize;
}

pub fn WriteDisk(inode: *FS.Inode, offset: isize, bufBegin: *void, bufSize: isize) callconv(.C) isize {
    const private: *Disk = @alignCast(@ptrCast(inode.private));
    private.write(private.private, @intCast(offset), bufBegin, @intCast(bufSize * inode.stat.blksize));
    return bufSize;
}

pub fn IOCtlDisk(inode: *FS.Inode, req: usize, data: *allowzero void) callconv(.C) isize {
    _ = data;
    const private: *Disk = @alignCast(@ptrCast(inode.private));
    if (req == 0x100) { // Refresh Partition Table
        private.Rescan();
    }
    return 0;
}

pub fn ReadPartition(inode: *FS.Inode, offset: isize, bufBegin: *void, bufSize: isize) callconv(.C) isize {
    const private: *Partition = @alignCast(@ptrCast(inode.private));
    if ((@as(u64, @intCast(offset + bufSize)) + private.startLBA) > private.endLBA) {
        return 0;
    }
    private.owner.read(private.owner.private, @as(usize, @intCast(offset)) + @as(usize, @intCast(private.startLBA)), bufBegin, @intCast(bufSize * inode.stat.blksize));
    return bufSize;
}

pub fn WritePartition(inode: *FS.Inode, offset: isize, bufBegin: *void, bufSize: isize) callconv(.C) isize {
    const private: *Partition = @alignCast(@ptrCast(inode.private));
    if ((@as(u64, @intCast(offset + bufSize)) + private.startLBA) > private.endLBA) {
        return 0;
    }
    private.owner.write(private.owner.private, @as(usize, @intCast(offset)) + @as(usize, @intCast(private.startLBA)), bufBegin, @intCast(bufSize * inode.stat.blksize));
    return bufSize;
}

pub fn UnlinkPartition(inode: *FS.Inode) callconv(.C) isize {
    const parent = inode.parent.?;
    const private: *Partition = @alignCast(@ptrCast(inode.private));
    private.owner.firstPartition = private.next;
    @as(*Spinlock, @ptrCast(&parent.lock)).acquire();
    FS.RemoveInodeFromParent(inode);
    @as(*Spinlock, @ptrCast(&parent.lock)).release();
    Memory.Pool.StaticPool.Free(@as([*]u8, @ptrCast(private))[0..@sizeOf(Partition)]);
    Memory.Pool.StaticPool.Free(@as([*]u8, @ptrCast(inode))[0..@sizeOf(FS.Inode)]);
    return 0;
}

pub fn RegisterDisk(
    name: []const u8,
    private: *allowzero void,
    blocks: u64,
    read: *const fn (*allowzero void, usize, *void, usize) callconv(.C) void,
    write: *const fn (*allowzero void, usize, *void, usize) callconv(.C) void,
) void {
    var inode = @as(*FS.Inode, @alignCast(@ptrCast(Memory.Pool.StaticPool.Alloc(@sizeOf(FS.Inode)).?.ptr))); // To Prevent them from being page swapped out if one of them contains the swap partition
    inode.stat.uid = 1;
    inode.stat.gid = 1;
    inode.stat.ctime = HAL.Arch.GetCurrentTimestamp()[0];
    inode.stat.mtime = inode.stat.ctime;
    inode.stat.atime = inode.stat.ctime;
    inode.stat.blksize = 512;
    inode.stat.blocks = @intCast(blocks);
    inode.stat.size = @intCast(blocks);
    inode.stat.mode = 0o0060660;
    inode.stat.nlinks = 1;
    inode.isVirtual = true;
    inode.read = &ReadDisk;
    inode.write = &WriteDisk;
    inode.ioctl = &IOCtlDisk;
    var disk = @as(*Disk, @alignCast(@ptrCast(Memory.Pool.StaticPool.Alloc(@sizeOf(Disk)).?.ptr)));
    disk.private = private;
    disk.inode = inode;
    disk.read = read;
    disk.write = write;
    inode.private = @alignCast(@ptrCast(disk));
    FS.DevFS.RegisterDevice(name, inode);
    disk.Rescan();
}
