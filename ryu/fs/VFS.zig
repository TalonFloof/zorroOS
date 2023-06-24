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

pub fn ReadDir(i: *Inode, off: usize) ?*Inode {
    fileLock.acquire();
    if (!i.hasReadEntries) {
        if (i.readdir) |readdir| {
            if (i.parent == null) {
                readdir(i, false);
            } else {
                readdir(i, true);
            }
            i.hasReadEntries = true;
        }
    }
    var ind: usize = 0;
    var ent: ?*Inode = i.children;
    while (ind < off) : (ind += 1) {
        if (ent == null) {
            fileLock.release();
            return null;
        }
        ent = ent.?.nextSibling;
    }
    fileLock.release();
    return ent;
}

pub fn FindDir(i: *Inode, name: []const u8) ?*Inode {
    if (!i.hasReadEntries) {
        if (i.readdir) |readdir| {
            if (i.parent == null) {
                readdir(i, false);
            } else {
                readdir(i, true);
            }
            i.hasReadEntries = true;
        }
    }
    var ent: ?*Inode = i.children;
    while (ent) |e| {
        const str: [*c]const u8 = @ptrCast([*c]const u8, &e.name);
        if (std.mem.eql(u8, name, str[0..std.mem.len(str)])) {
            break;
        }
        ent = e.nextSibling;
    }
    return ent;
}

pub fn GetInode(path: []const u8, base: *Inode) ?*Inode {
    fileLock.acquire();
    var curNode: ?*Inode = base;
    var iter = std.mem.split(u8, path[path.len], "/");
    while (iter.next()) |name| {
        if (std.mem.eql(u8, name, "..")) {
            curNode = curNode.?.parent;
        } else if (name.len == 0 or std.mem.eql(u8, name, ".")) {
            continue;
        } else {
            curNode = FindDir(curNode.?, name);
        }
        if (curNode == null) {
            break;
        }
    }
    fileLock.release();
    return curNode;
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
