const std = @import("std");
const FS = @import("root").FS;
const Spinlock = @import("root").Spinlock;
const HAL = @import("root").HAL;
const Framebuffer = @import("Framebuffer.zig");

var nextDevID: isize = 2;

pub fn RegisterDevice(name: []const u8, inode: *FS.Inode) void {
    var devNode = FS.GetInode("/dev", FS.rootInode.?).?;
    var id = nextDevID;
    _ = id;
    inode.parent = devNode;
    inode.mountOwner = devNode.mountPoint;
    inode.stat.ID = nextDevID;
    @memset(inode.name[0..256], 0);
    @memcpy(inode.name[0..name.len], name);
    FS.fileLock.acquire();
    FS.AddInodeToParent(inode);
    FS.fileLock.release();
    nextDevID += 1;
}

//////// Basic UNIX Devices ////////

pub fn ReadZero(inode: *FS.Inode, offset: isize, bufBegin: *void, bufSize: isize) callconv(.C) isize {
    _ = offset;
    _ = inode;
    @memset(@ptrCast([*]u8, @alignCast(@alignOf([*]u8), bufBegin))[0..@intCast(usize, bufSize)], 0);
    return bufSize;
}

pub fn ReadWriteNull(inode: *FS.Inode, offset: isize, bufBegin: *void, bufSize: isize) callconv(.C) isize {
    _ = bufSize;
    _ = bufBegin;
    _ = offset;
    _ = inode;
    return 0;
}

var zeroFile: FS.Inode = FS.Inode{
    .stat = FS.Metadata{
        .mode = 0o0020666, // wut da heck, its dat number
    },
    .read = &ReadZero,
    .write = &ReadWriteNull,
};

var nullFile: FS.Inode = FS.Inode{
    .stat = FS.Metadata{
        .mode = 0o0020666, // wut da heck, its dat number
    },
    .read = &ReadWriteNull,
    .write = &ReadWriteNull,
};
////////////////////////////////////

pub fn Mount(fs: *FS.Filesystem) callconv(.C) bool {
    if (fs.root.children != null) {
        return false;
    }
    fs.root.mountPoint = fs;
    fs.root.hasReadEntries = true;
    fs.root.stat.ID = 1;
    fs.root.stat.mode = 0o0040555;
    return true;
}

pub fn UMount(fs: *FS.Filesystem) callconv(.C) void {
    _ = fs;
}

pub fn Init() void {
    FS.RegisterFilesystem("devfs", &Mount, &UMount);
    if (!FS.Mount(FS.GetInode("/dev", FS.rootInode.?).?, null, "devfs")) {
        HAL.Crash.Crash(.RyuKernelInitializationFailure, .{ 0x2001, 0, 0, 0 });
    }
    RegisterDevice("null", &nullFile);
    RegisterDevice("zero", &zeroFile);
    Framebuffer.Init();
}
