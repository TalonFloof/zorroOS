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

pub fn Init() void {}
