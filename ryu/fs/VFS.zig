const Memory = @import("root").Memory;
pub const Inode = @import("devlib").fs.Inode;
pub const Metadata = @import("devlib").fs.Metadata;
pub const Filesystem = @import("devlib").fs.Filesystem;
const Spinlock = @import("root").Spinlock;
const HAL = @import("root").HAL;
const std = @import("std");
pub const DevFS = @import("DevFS.zig");
pub const CpioFS = @import("CpioFS.zig");

pub var rootInode: ?*Inode = null;

const FSType = struct {
    prev: ?*FSType,
    next: ?*FSType,
    name: []const u8,
    mount: *const fn (*Filesystem) callconv(.C) bool,
    umount: *const fn (*Filesystem) callconv(.C) void,
};

var fsHead: ?*FSType = null;
var fsTail: ?*FSType = null;
var fsLock: Spinlock = .unaquired;

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
    @ptrCast(*Spinlock, &rootInode.?.lock).acquire();
    var inode: *Inode = @ptrCast(*Inode, @alignCast(@alignOf(*Inode), Memory.Pool.PagedPool.Alloc(@sizeOf(Inode)).?.ptr));
    @memset(@intToPtr([*]u8, @ptrToInt(&inode.name))[0..256], 0);
    @memcpy(@intToPtr([*]u8, @ptrToInt(&inode.name)), name);
    inode.parent = rootInode;
    inode.children = null;
    inode.stat.ID = 2;
    inode.stat.uid = 1;
    inode.stat.gid = 1;
    inode.stat.nlinks = 1;
    inode.stat.mode = 0o0040755;
    AddInodeToParent(inode);
    @ptrCast(*Spinlock, &rootInode.?.lock).release();
    return inode;
}

pub fn ReadDir(i: *Inode, off: usize) ?*Inode {
    @ptrCast(*Spinlock, &i.lock).acquire();
    if (!i.hasReadEntries) {
        if (i.readdir) |readdir| {
            if (i.parent == null) {
                _ = readdir(i, false);
            } else {
                _ = readdir(i, true);
            }
            i.hasReadEntries = true;
        }
    }
    var ind: usize = 0;
    var ent: ?*Inode = i.children;
    while (ind < off) : (ind += 1) {
        if (ent == null) {
            @ptrCast(*Spinlock, &i.lock).release();
            return null;
        }
        ent = ent.?.nextSibling;
    }
    @ptrCast(*Spinlock, &i.lock).release();
    return ent;
}

pub fn FindDir(i: *Inode, name: []const u8) ?*Inode {
    if (!i.hasReadEntries) {
        if (i.readdir) |readdir| {
            if (i.parent == null) {
                _ = readdir(i, false);
            } else {
                _ = readdir(i, true);
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
    var curNode: ?*Inode = base;
    var iter = std.mem.split(u8, path, "/");
    while (iter.next()) |name| {
        if (std.mem.eql(u8, name, "..")) {
            curNode = curNode.?.parent;
        } else if (name.len == 0 or std.mem.eql(u8, name, ".")) {
            continue;
        } else {
            const lock = @ptrCast(*Spinlock, &curNode.?.lock);
            lock.acquire();
            curNode = FindDir(curNode.?, name);
            lock.release();
        }
        if (curNode == null) {
            break;
        }
    }
    return curNode;
}

pub fn Mount(inode: *Inode, dev: ?*Inode, fs: []const u8) bool {
    fsLock.acquire();
    // Find Filesystem
    var index = fsHead;
    while (index) |i| {
        if (std.mem.eql(u8, fs, i.name)) {
            break;
        }
        index = i.next;
    }
    if (index == null) {
        fsLock.release();
        return false;
    }
    var newFS: *Filesystem = @ptrCast(*Filesystem, @alignCast(@alignOf(*Filesystem), Memory.Pool.PagedPool.Alloc(@sizeOf(Filesystem)).?.ptr));
    newFS.dev = dev;
    newFS.root = inode;
    newFS.mount = index.?.mount;
    newFS.umount = index.?.umount;
    fsLock.release();
    var result = newFS.mount(newFS);
    if (!result) {
        Memory.Pool.PagedPool.Free(@intToPtr([*]u8, @ptrToInt(newFS))[0..@sizeOf(Filesystem)]);
    } else {
        HAL.Console.Put("Successfully mounted filesystem {s} to inode named \"{s}\"\n", .{ fs, newFS.root.name[0..std.mem.len(@ptrCast([*c]const u8, &newFS.root.name))] });
    }
    return result;
}

pub fn RegisterFilesystem(name: []const u8, mount: *const fn (*Filesystem) callconv(.C) bool, umount: *const fn (*Filesystem) callconv(.C) void) void {
    fsLock.acquire();
    var newFSType: *FSType = @ptrCast(*FSType, @alignCast(@alignOf(*FSType), Memory.Pool.PagedPool.Alloc(@sizeOf(FSType)).?.ptr));
    newFSType.name = name;
    newFSType.mount = mount;
    newFSType.umount = umount;
    newFSType.next = null;
    newFSType.prev = fsTail;
    if (fsTail) |tail| {
        tail.next = newFSType;
    }
    fsTail = newFSType;
    if (fsHead == null) {
        fsHead = newFSType;
    }
    fsLock.release();
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
    _ = NewDirInode("dev");
    DevFS.Init();
}
