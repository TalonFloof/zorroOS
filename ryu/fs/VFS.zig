const Memory = @import("root").Memory;
pub const Inode = @import("devlib").fs.Inode;
pub const Metadata = @import("devlib").fs.Metadata;
pub const Filesystem = @import("devlib").fs.Filesystem;
const Spinlock = @import("root").Spinlock;
const HAL = @import("root").HAL;
const std = @import("std");
pub const DevFS = @import("DevFS.zig");
pub const CpioFS = @import("CpioFS.zig");
pub const MesgFS = @import("MesgFS.zig");

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

pub fn RemoveInodeFromParent(i: *Inode) void {
    if (i.prevSibling) |prev| {
        prev.nextSibling = i.nextSibling;
    }
    if (i.nextSibling) |next| {
        next.prevSibling = i.prevSibling;
    }
    if (@intFromPtr(i.parent.?.children) == @intFromPtr(i)) {
        i.parent.?.children = i.nextSibling;
    }
    i.parent = null;
}

pub fn NewDirInode(name: []const u8) *Inode {
    @as(*Spinlock, @ptrCast(&rootInode.?.lock)).acquire();
    var inode: *Inode = @as(*Inode, @ptrCast(@alignCast(Memory.Pool.PagedPool.Alloc(@sizeOf(Inode)).?.ptr)));
    @memset(@as([*]u8, @ptrFromInt(@intFromPtr(&inode.name)))[0..256], 0);
    @memcpy(@as([*]u8, @ptrFromInt(@intFromPtr(&inode.name))), name);
    inode.parent = rootInode;
    inode.children = null;
    inode.stat.ID = 2;
    inode.stat.uid = 1;
    inode.stat.gid = 1;
    inode.stat.nlinks = 1;
    inode.stat.mode = 0o0040755;
    AddInodeToParent(inode);
    @as(*Spinlock, @ptrCast(&rootInode.?.lock)).release();
    return inode;
}

pub fn ReadDir(i: *Inode, off: usize) ?*Inode {
    @as(*Spinlock, @ptrCast(&i.lock)).acquire();
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
            @as(*Spinlock, @ptrCast(&i.lock)).release();
            return null;
        }
        ent = ent.?.nextSibling;
    }
    @as(*Spinlock, @ptrCast(&i.lock)).release();
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
        const str: [*c]const u8 = @as([*c]const u8, @ptrCast(&e.name));
        if (std.mem.eql(u8, name, str[0..std.mem.len(str)])) {
            break;
        }
        ent = e.nextSibling;
    }
    return ent;
}

pub fn GetInode(path: []const u8, base: *Inode) ?*Inode {
    var curNode: ?*Inode = if (std.mem.startsWith(u8, path, "/")) rootInode else base;
    var iter = std.mem.split(u8, path, "/");
    while (iter.next()) |name| {
        if (std.mem.eql(u8, name, "..")) {
            curNode = curNode.?.parent;
        } else if (name.len == 0 or std.mem.eql(u8, name, ".")) {
            continue;
        } else {
            const lock = @as(*Spinlock, @ptrCast(&curNode.?.lock));
            const old = HAL.Arch.IRQEnableDisable(false);
            lock.acquire();
            curNode = FindDir(curNode.?, name);
            lock.release();
            _ = HAL.Arch.IRQEnableDisable(old);
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
    var newFS: *Filesystem = @as(*Filesystem, @ptrCast(@alignCast(Memory.Pool.PagedPool.Alloc(@sizeOf(Filesystem)).?.ptr)));
    newFS.dev = dev;
    newFS.root = inode;
    newFS.mount = index.?.mount;
    newFS.umount = index.?.umount;
    fsLock.release();
    var result = newFS.mount(newFS);
    if (!result) {
        Memory.Pool.PagedPool.Free(@as([*]u8, @ptrFromInt(@intFromPtr(newFS)))[0..@sizeOf(Filesystem)]);
    } else {
        HAL.Console.Put("Successfully mounted filesystem {s} to inode named \"{s}\"\n", .{ fs, newFS.root.name[0..std.mem.len(@as([*c]const u8, @ptrCast(&newFS.root.name)))] });
    }
    return result;
}

pub fn RegisterFilesystem(name: []const u8, mount: *const fn (*Filesystem) callconv(.C) bool, umount: *const fn (*Filesystem) callconv(.C) void) void {
    fsLock.acquire();
    var newFSType: *FSType = @as(*FSType, @ptrCast(@alignCast(Memory.Pool.PagedPool.Alloc(@sizeOf(FSType)).?.ptr)));
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
    rootInode = @as(*Inode, @ptrCast(@alignCast(Memory.Pool.PagedPool.Alloc(@sizeOf(Inode)).?.ptr)));
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
    MesgFS.Init();
}
