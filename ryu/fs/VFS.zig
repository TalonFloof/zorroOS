const Memory = @import("root").Memory;
pub const Inode = @import("devlib").fs.Inode;
pub const DirEntry = @import("devlib").DirEntry;
pub const Metadata = @import("devlib").Metadata;
const Spinlock = @import("root").Spinlock;
const HAL = @import("root").HAL;
const std = @import("std");
const DevFS = @import("DevFS.zig");

var rootInode: ?*Inode = null;
var nextID: i64 = 2;
var fileLock: Spinlock = .unaquired;

pub fn AddInodeToParent(i: *Inode) void {
    i.prevSibling = null;
    if (i.parent.?.children) |head| {
        head.prevSibling = i;
        i.nextSibling = head;
    } else {
        i.nextSibling = null;
    }
    i.parent.?.children = i;
}

pub fn NewDirInode(name: []const u8) *Inode {
    fileLock.acquire();
    var inode: *Inode = @ptrCast(*Inode, @alignCast(@alignOf(*Inode), Memory.Pool.PagedPool.Alloc(@sizeOf(Inode)).?.ptr));
    @memset(@intToPtr([*]u8, @ptrToInt(&inode.name))[0..256], 0);
    @memcpy(@intToPtr([*]u8, @ptrToInt(&inode.name)), name);
    inode.parent = rootInode;
    inode.children = null;
    inode.stat.ID = 1;
    inode.stat.uid = 1;
    inode.stat.gid = 1;
    inode.stat.nlinks = 1;
    inode.stat.mode = 0o0040755;
    AddInodeToParent(inode);
    return inode;
}

pub fn Init() void {
    rootInode = @ptrCast(*Inode, @alignCast(@alignOf(*Inode), Memory.Pool.PagedPool.Alloc(@sizeOf(Inode)).?.ptr));
    rootInode.?.stat.ID = 1;
    rootInode.?.stat.uid = 1;
    rootInode.?.stat.gid = 1;
    rootInode.?.stat.nlinks = 1;
    rootInode.?.stat.mode = 0o0040755;
    rootInode.?.children = null;
    rootInode.?.nextSibling = null;
    rootInode.?.prevSibling = null;
    var devInode = NewDirInode("dev");
    _ = devInode;
}
