const Memory = @import("root").Memory;
const std = @import("std");
const FS = @import("root").FS;
const HAL = @import("root").HAL;

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
        if (@ptrToInt(inode.private) != 0) {
            const data: []u8 = @ptrCast([*]u8, @alignCast(1, inode.private))[0..@intCast(usize, inode.stat.size)];
            const readData: []u8 = data[@intCast(usize, @min(inode.stat.size, @intCast(i64, offset)))..@intCast(usize, @min(inode.stat.size, @intCast(i64, offset + bufSize)))];
            @memcpy(@ptrCast([*]u8, @alignCast(@alignOf([*]u8), bufBegin))[0..readData.len], readData);
            return @intCast(isize, readData.len);
        } else {
            return 0;
        }
    }
    return -21;
}

pub fn Write(inode: *FS.Inode, offset: isize, bufBegin: *void, bufSize: isize) callconv(.C) isize {
    if ((inode.stat.mode & 0o0770000) != 0o0040000) {
        if (inode.stat.size < @intCast(usize, offset + bufSize)) {
            if (@intCast(usize, inode.stat.reserved3) < @intCast(usize, offset + bufSize)) {
                // Resize
                const newSize: usize = if (inode.stat.reserved3 == 0) @intCast(usize, offset + bufSize) else if ((@intCast(usize, offset + bufSize) % 4096) != 0) ((@intCast(usize, offset + bufSize) / 4096) * 4096) + 4096 else @intCast(usize, offset + bufSize);
                var newBuf = if (newSize < 4081) Memory.Pool.PagedPool.Alloc(newSize).? else Memory.Pool.PagedPool.AllocAnonPages(newSize).?;
                const data: []u8 = @ptrCast([*]u8, @alignCast(1, inode.private))[0..@intCast(usize, inode.stat.size)];
                @memcpy(newBuf[0..data.len], data);
                if (data.len < 4081) {
                    Memory.Pool.PagedPool.Free(data);
                } else {
                    Memory.Pool.PagedPool.FreeAnonPages(data);
                }
                inode.stat.reserved3 = @intCast(u64, newSize);
                inode.private = @ptrCast(*allowzero void, @alignCast(@alignOf(*allowzero void), newBuf.ptr));
            }
            inode.stat.size = @intCast(i64, offset + bufSize);
        }
        const data: []u8 = @ptrCast([*]u8, @alignCast(1, inode.private))[0..@intCast(usize, inode.stat.size)];
        @memcpy(data[@intCast(usize, offset)..@intCast(usize, offset + bufSize)], @ptrCast([*]u8, @alignCast(1, bufBegin))[0..@intCast(usize, bufSize)]);
        return bufSize;
    }
    return -21;
}

pub fn Truncate(inode: *FS.Inode, size: isize) callconv(.C) isize {
    if (@ptrToInt(inode.private) == 0) {
        return 0;
    }
    if (size == 0) {
        inode.stat.size = 0;
        if (inode.stat.reserved3 < 4081) {
            Memory.Pool.PagedPool.Free(@ptrCast([*]u8, @alignCast(1, inode.private))[0..inode.stat.reserved3]);
        } else {
            Memory.Pool.PagedPool.FreeAnonPages(@ptrCast([*]u8, @alignCast(1, inode.private))[0..inode.stat.reserved3]);
        }
        inode.private = @intToPtr(*allowzero void, 0);
        inode.stat.reserved3 = 0;
    } else {
        // this will be improved in the near future
        inode.stat.size = size;
    }
    return inode.stat.size;
}

pub fn Create(inode: *FS.Inode, name: [*c]const u8, mode: usize) callconv(.C) isize {
    FS.fileLock.acquire();
    const id = nextInodeID;
    const len: usize = std.mem.len(name);
    var in: *FS.Inode = @ptrCast(*FS.Inode, @alignCast(@alignOf(*FS.Inode), Memory.Pool.PagedPool.Alloc(@sizeOf(FS.Inode)).?.ptr));
    @memset(@intToPtr([*]u8, @ptrToInt(&in.name))[0..256], 0);
    @memcpy(@intToPtr([*]u8, @ptrToInt(&in.name))[0..len], name[0..len]);
    in.hasReadEntries = true;
    in.stat.ID = id;
    in.stat.nlinks = 1;
    in.stat.uid = 1;
    in.stat.gid = 1;
    in.stat.mode = @intCast(i32, mode);
    in.stat.reserved3 = 0; // reserved3 is used to store the capacity of the file's data (not the size!)
    in.mountOwner = inode.mountOwner;
    in.create = &Create;
    in.read = &Read;
    in.write = &Write;
    in.trunc = &Truncate;
    nextInodeID += 1;
    FS.fileLock.release();
    return 0;
}

pub fn Mount(fs: *FS.Filesystem) callconv(.C) bool {
    fs.root.mountPoint = fs;
    fs.root.hasReadEntries = true;
    fs.root.stat.mode = 0o0040755;
    fs.root.create = &Create;
    fs.root.read = &Read;
    fs.root.write = &Write;
    fs.root.trunc = &Truncate;
    return true;
}

pub fn UMount(fs: *FS.Filesystem) callconv(.C) void {
    _ = fs;
}

pub fn Init(image: []u8) void {
    FS.RegisterFilesystem("cpioFS", &Mount, &UMount);
    _ = FS.Mount(FS.rootInode.?, null, "cpioFS");
    var i: usize = @ptrToInt(image.ptr);
    while (@intToPtr(*CPIOHeader, i).magic == 0o070707) {
        const header: *CPIOHeader = @intToPtr(*CPIOHeader, i);
        const fileSize: usize = @intCast(usize, (@intCast(u32, header.fileSizeMS) << 16) | @intCast(u32, header.fileSizeLS));
        const path: []const u8 = @intToPtr([*]const u8, i + @sizeOf(CPIOHeader))[0..(header.nameSize - 1)];
        const data: []const u8 = @intToPtr([*]const u8, i + @sizeOf(CPIOHeader) + header.nameSize)[0..fileSize];
        var node = FS.rootInode.?;
        var iter = std.mem.split(u8, path, "/");
        const pathCount = std.mem.count(u8, path, "/");
        var index: usize = 0;
        while (iter.next()) |name| {
            if (index == pathCount - 1) {
                if (!std.mem.eql(u8, name, "...")) {
                    _ = node.create.?(node, @ptrCast([*c]const u8, name.ptr), @intCast(usize, header.mode));
                    const n = FS.GetInode(name, node).?;
                    _ = n.write.?(n, 0, @ptrCast(*void, @constCast(@alignCast(@alignOf(*void), data.ptr))), @intCast(isize, data.len));
                }
            } else {
                if (FS.GetInode(name, node)) |n| {
                    node = n;
                } else {
                    _ = node.create.?(node, @ptrCast([*c]const u8, name.ptr), 0o0040755);
                    node = FS.GetInode(name, node).?;
                }
            }
            index += 1;
        }
        i += @sizeOf(CPIOHeader) + header.nameSize + fileSize;
    }
    i = 0;
    while (i < image.len) : (i += 4096) {
        Memory.PFN.DereferencePage((@ptrToInt(image.ptr) - 0xffff800000000000) + i);
    }
}
