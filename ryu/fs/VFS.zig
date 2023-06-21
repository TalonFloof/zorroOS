const Memory = @import("root").Memory;
pub const Inode = @import("devlib").fs.Inode;
pub const DirEntry = @import("devlib").DirEntry;
pub const Metadata = @import("devlib").Metadata;
const Spinlock = @import("root").Spinlock;
const HAL = @import("root").HAL;
const std = @import("std");
const DevFS = @import("DevFS.zig");

var rootInode: ?*Inode = null;
var fileLock: Spinlock = .unaquired;

pub fn NewDirInode(name: []const u8) *Inode {
    var inode: *Inode = @ptrCast(*Inode, @alignCast(@alignOf(*Inode), Memory.Pool.PagedPool.Alloc(@sizeOf(Inode)).?.ptr));
    @memset(@intToPtr([*]u8, @ptrToInt(&inode.name))[0..256], 0);
    @memcpy(@intToPtr([*]u8, @ptrToInt(&inode.name)), name);
}

pub fn Init() void {}
