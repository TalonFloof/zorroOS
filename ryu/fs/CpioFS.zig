const Memory = @import("root").Memory;
const std = @import("std");
const FS = @import("root").FS;
const HAL = @import("root").HAL;
const Spinlock = @import("root").Spinlock;

const CPIOHeader = extern struct {
    magic: u16 align(1),
    dev: u16 align(1),
    ino: u16 align(1),
    mode: u16 align(1),
    uid: u16 align(1),
    gid: u16 align(1),
    nlinks: u16 align(1),
    rdev: u16 align(1),
    mtimeMS: u16 align(1),
    mtimeLS: u16 align(1),
    nameSize: u16 align(1),
    fileSizeMS: u16 align(1),
    fileSizeLS: u16 align(1),
    // NUL-terminated Name follows this Header, file data follows the name.
};

var nextInodeID: i64 = 3;

pub fn Read(inode: *FS.Inode, offset: isize, bufBegin: *void, bufSize: isize) callconv(.C) isize {
    if ((inode.stat.mode & 0o0770000) != 0o0040000) {
        if (@intFromPtr(inode.private) != 0) {
            const data: []u8 = @as([*]u8, @ptrCast(@alignCast(inode.private)))[0..@as(usize, @intCast(inode.stat.size))];
            const readData: []u8 = data[@as(usize, @intCast(@min(inode.stat.size, @as(i64, @intCast(offset)))))..@as(usize, @intCast(@min(inode.stat.size, @as(i64, @intCast(offset + bufSize)))))];
            @memcpy(@as([*]u8, @ptrCast(@alignCast(bufBegin)))[0..readData.len], readData);
            return @as(isize, @intCast(readData.len));
        } else {
            return 0;
        }
    }
    return -21;
}

pub fn Write(inode: *FS.Inode, offset: isize, bufBegin: *void, bufSize: isize) callconv(.C) isize {
    if ((inode.stat.mode & 0o0770000) != 0o0040000) {
        if (bufSize == 0) {
            return 0;
        }
        if (inode.stat.size < @as(usize, @intCast(offset + bufSize))) {
            if (@as(usize, @intCast(inode.stat.reserved3)) < @as(usize, @intCast(offset + bufSize))) {
                // Resize
                const newSize: usize = if (inode.stat.reserved3 == 0) @as(usize, @intCast(offset + bufSize)) else if ((@as(usize, @intCast(offset + bufSize)) % 4096) != 0) ((@as(usize, @intCast(offset + bufSize)) / 4096) * 4096) + 4096 else @as(usize, @intCast(offset + bufSize));
                var newBuf = if (newSize < 4081) Memory.Pool.PagedPool.Alloc(newSize).? else Memory.Pool.PagedPool.AllocAnonPages(newSize).?;
                if (@intFromPtr(inode.private) != 0) {
                    const data: []u8 = @as([*]u8, @ptrCast(@alignCast(inode.private)))[0..@as(usize, @intCast(inode.stat.size))];
                    @memcpy(newBuf[0..data.len], data);
                    if (data.len < 4081) {
                        Memory.Pool.PagedPool.Free(data);
                    } else {
                        Memory.Pool.PagedPool.FreeAnonPages(data);
                    }
                }
                inode.stat.reserved3 = @as(u64, @intCast(newSize));
                inode.private = @as(*allowzero void, @ptrCast(@alignCast(newBuf.ptr)));
            }
            inode.stat.size = @as(i64, @intCast(offset + bufSize));
        }
        const data: []u8 = @as([*]u8, @ptrCast(@alignCast(inode.private)))[0..@as(usize, @intCast(inode.stat.size))];
        @memcpy(data[@as(usize, @intCast(offset))..@as(usize, @intCast(offset + bufSize))], @as([*]u8, @ptrCast(@alignCast(bufBegin)))[0..@as(usize, @intCast(bufSize))]);
        return bufSize;
    }
    return -21;
}

pub fn Truncate(inode: *FS.Inode, size: isize) callconv(.C) isize {
    if (@intFromPtr(inode.private) == 0) {
        return 0;
    }
    if (size == 0) {
        inode.stat.size = 0;
        if (inode.stat.reserved3 < 4081) {
            Memory.Pool.PagedPool.Free(@as([*]u8, @ptrCast(@alignCast(inode.private)))[0..inode.stat.reserved3]);
        } else {
            Memory.Pool.PagedPool.FreeAnonPages(@as([*]u8, @ptrCast(@alignCast(inode.private)))[0..inode.stat.reserved3]);
        }
        inode.private = @as(*allowzero void, @ptrFromInt(0));
        inode.stat.reserved3 = 0;
    } else {
        // this will be improved in the near future
        inode.stat.size = size;
    }
    return inode.stat.size;
}

pub fn Create(inode: *FS.Inode, name: [*c]const u8, mode: usize) callconv(.C) isize {
    const id = @atomicRmw(i64, &nextInodeID, .Add, 1, .Monotonic);
    const len: usize = std.mem.len(name);
    var in: *FS.Inode = @as(*FS.Inode, @ptrCast(@alignCast(Memory.Pool.PagedPool.Alloc(@sizeOf(FS.Inode)).?.ptr)));
    @memset(@as([*]u8, @ptrFromInt(@intFromPtr(&in.name)))[0..256], 0);
    @memcpy(@as([*]u8, @ptrFromInt(@intFromPtr(&in.name)))[0..len], name[0..len]);
    in.stat.ID = id;
    in.stat.nlinks = 1;
    in.stat.uid = 1;
    in.stat.gid = 1;
    in.stat.mode = @as(i32, @intCast(mode));
    in.stat.reserved3 = 0; // reserved3 is used to store the capacity of the file's data (not the size!)
    in.stat.size = 0;
    const time: [2]i64 = HAL.Arch.GetCurrentTimestamp();
    in.stat.ctime = time[0];
    in.stat.reserved1 = @bitCast(time[1]);
    in.stat.mtime = time[0];
    in.stat.reserved2 = @bitCast(time[1]);
    in.stat.atime = time[0];
    in.isVirtual = true;
    in.mountOwner = inode.mountOwner;
    in.parent = inode;
    in.create = &Create;
    in.read = &Read;
    in.write = &Write;
    in.trunc = &Truncate;
    in.unlink = &Unlink;
    in.lock = 0;
    FS.AddInodeToParent(in);
    return 0;
}

pub fn Unlink(inode: *FS.Inode) callconv(.C) isize {
    if ((inode.stat.mode & 0o0770000) == 0o0040000 and inode.children != null) {
        return -39;
    }
    if ((inode.stat.mode & 0o0770000) != 0o0040000) {
        _ = inode.trunc.?(inode, 0);
    }
    const parent = inode.parent.?;
    @as(*Spinlock, @ptrCast(&parent.lock)).acquire();
    FS.RemoveInodeFromParent(inode);
    @as(*Spinlock, @ptrCast(&parent.lock)).release();
    Memory.Pool.PagedPool.Free(@as([*]u8, @ptrCast(inode))[0..@sizeOf(FS.Inode)]);
    return 0;
}

pub fn Mount(fs: *FS.Filesystem) callconv(.C) bool {
    fs.root.mountPoint = fs;
    fs.root.stat.mode = 0o0040755;
    fs.root.create = &Create;
    fs.root.read = &Read;
    fs.root.write = &Write;
    fs.root.trunc = &Truncate;
    fs.root.unlink = &Unlink;
    return true;
}

pub fn UMount(fs: *FS.Filesystem) callconv(.C) void {
    _ = fs;
}

pub fn Init(image: []u8) void {
    FS.RegisterFilesystem("cpioFS", &Mount, &UMount);
    _ = FS.Mount(FS.rootInode.?, null, "cpioFS");
    var i: usize = @intFromPtr(image.ptr);
    while (true) {
        const header: *CPIOHeader = @as(*CPIOHeader, @ptrFromInt(i));
        const fileSize: usize = @as(usize, @intCast((@as(u32, @intCast(header.fileSizeMS)) << 16) | @as(u32, @intCast(header.fileSizeLS))));
        const path: []const u8 = @as([*]const u8, @ptrFromInt(i + @sizeOf(CPIOHeader)))[0..(header.nameSize - 1)];
        if (std.mem.eql(u8, path, "TRAILER!!!")) {
            break;
        }
        const data: []const u8 = @as([*]const u8, @ptrFromInt(i + @sizeOf(CPIOHeader) + header.nameSize + (header.nameSize % 2)))[0..fileSize];
        var node: *FS.Inode = FS.rootInode.?;
        var iter = std.mem.split(u8, path, "/");
        var pathCount: usize = 0;
        while (iter.next() != null) {
            pathCount += 1;
        }
        iter = std.mem.split(u8, path, "/");
        var index: usize = 1;
        while (iter.next()) |name| {
            if (index == pathCount) {
                if (!std.mem.eql(u8, name, "...")) {
                    var cName: [256]u8 = [_]u8{0} ** 256;
                    @memcpy(cName[0..name.len], name);
                    @as(*Spinlock, @ptrCast(&node.lock)).acquire();
                    _ = node.create.?(node, @as([*c]const u8, @ptrCast(&cName)), @as(usize, @intCast(header.mode)));
                    @as(*Spinlock, @ptrCast(&node.lock)).release();
                    const n = FS.GetInode(name, node, false).?;
                    @as(*Spinlock, @ptrCast(&n.lock)).acquire();
                    _ = n.write.?(n, 0, @as(*void, @ptrFromInt(@intFromPtr(data.ptr))), @as(isize, @intCast(data.len)));
                    @as(*Spinlock, @ptrCast(&n.lock)).release();
                }
            } else {
                if (FS.GetInode(name, node, false)) |n| {
                    node = n;
                } else {
                    var cName: [256]u8 = [_]u8{0} ** 256;
                    @memcpy(cName[0..name.len], name);
                    @as(*Spinlock, @ptrCast(&node.lock)).acquire();
                    _ = node.create.?(node, @as([*c]const u8, @ptrCast(&cName)), 0o0040755);
                    @as(*Spinlock, @ptrCast(&node.lock)).release();
                    node = FS.GetInode(name, node, false).?;
                }
            }
            index += 1;
        }
        i += @sizeOf(CPIOHeader) + header.nameSize + (header.nameSize % 2) + fileSize + (fileSize % 2);
    }
    i = 0;
    while (i < image.len) : (i += 4096) {
        Memory.PFN.ForceFreePage((@intFromPtr(image.ptr) - 0xffff800000000000) + i);
    }
}
