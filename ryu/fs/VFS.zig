const Memory = @import("root").Memory;
pub const Inode = @import("devlib").fs.Inode;
pub const Metadata = @import("devlib").fs.Metadata;
pub const Filesystem = @import("devlib").fs.Filesystem;
pub const DirEntry = @import("devlib").fs.DirEntry;
const Spinlock = @import("root").Spinlock;
const HAL = @import("root").HAL;
const std = @import("std");
pub const DevFS = @import("DevFS.zig");
pub const CpioFS = @import("CpioFS.zig");
pub const MesgFS = @import("MesgFS.zig");
pub const Disks = @import("Disks.zig");

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
    i.parent.?.virtualChildren += 1;
}

pub fn AddPhysicalInodeToParent(i: *Inode) void {
    i.prevSibling = null;
    if (i.parent.?.physChildren) |head| {
        head.prevSibling = i;
        i.nextSibling = head;
    } else {
        i.nextSibling = null;
    }
    i.parent.?.physChildren = i;
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
    i.parent.?.virtualChildren -= 1;
    i.parent = null;
}

pub fn RemovePhysicalInodeFromParent(i: *Inode) void {
    if (i.prevSibling) |prev| {
        prev.nextSibling = i.nextSibling;
    }
    if (i.nextSibling) |next| {
        next.prevSibling = i.prevSibling;
    }
    if (@intFromPtr(i.parent.?.physChildren) == @intFromPtr(i)) {
        i.parent.?.physChildren = i.nextSibling;
    }
    i.parent = null;
}

pub fn NewDirInode(name: []const u8) *Inode {
    @as(*Spinlock, @ptrCast(&rootInode.?.lock)).acquire();
    var inode: *Inode = @as(*Inode, @ptrCast(@alignCast(Memory.Pool.PagedPool.Alloc(@sizeOf(Inode)).?.ptr)));
    @memset(@as([*]u8, @ptrFromInt(@intFromPtr(&inode.name)))[0..256], 0);
    @memcpy(@as([*]u8, @ptrFromInt(@intFromPtr(&inode.name))), name);
    inode.parent = rootInode;
    inode.isVirtual = true;
    inode.children = null;
    inode.physChildren = null;
    inode.stat.ID = 2;
    inode.stat.uid = 1;
    inode.stat.gid = 1;
    inode.stat.nlinks = 1;
    inode.stat.mode = 0o0040755;
    const time: [2]i64 = HAL.Arch.GetCurrentTimestamp();
    inode.stat.ctime = time[0];
    inode.stat.reserved1 = @bitCast(time[1]);
    inode.stat.mtime = time[0];
    inode.stat.reserved2 = @bitCast(time[1]);
    inode.stat.atime = time[0];
    inode.stat.reserved3 = @bitCast(time[1]);
    AddInodeToParent(inode);
    @as(*Spinlock, @ptrCast(&rootInode.?.lock)).release();
    return inode;
}

pub fn ReadDir(i: *Inode, off: usize) ?DirEntry {
    @as(*Spinlock, @ptrCast(&i.lock)).acquire();
    var ent: DirEntry = DirEntry{};
    if (off < i.virtualChildren) {
        var vnode = i.children;
        var ind: usize = 0;
        while (ind < off) : (ind += 1) {
            vnode = vnode.?.nextSibling;
        }
        ent.inodeID = vnode.?.stat.ID;
        ent.mode = vnode.?.stat.mode;
        ent.nameLen = @intCast(std.mem.len(@as([*c]const u8, @ptrCast(&vnode.?.name))));
        ent.name = vnode.?.name;
        @as(*Spinlock, @ptrCast(&i.lock)).release();
        return ent;
    } else {
        if (i.readdir) |readdir| {
            const result: isize = readdir(i, off, &ent);
            @as(*Spinlock, @ptrCast(&i.lock)).release();
            if (result > 0) {
                return ent;
            }
            return null;
        }
        @as(*Spinlock, @ptrCast(&i.lock)).release();
        return null;
    }
}

pub fn FindDir(i: *Inode, name: []const u8) ?*Inode {
    var ent: ?*Inode = i.physChildren;
    while (ent) |e| {
        const str: [*c]const u8 = @as([*c]const u8, @ptrCast(&e.name));
        if (std.mem.eql(u8, name, str[0..std.mem.len(str)])) {
            return ent;
        }
        ent = e.nextSibling;
    }
    ent = i.children;
    while (ent) |e| {
        const str: [*c]const u8 = @as([*c]const u8, @ptrCast(&e.name));
        if (std.mem.eql(u8, name, str[0..std.mem.len(str)])) {
            return ent;
        }
        ent = e.nextSibling;
    }
    if (i.finddir != null) {
        return i.finddir.?(i, @ptrCast(name.ptr), name.len);
    } else {
        return null;
    }
}

pub fn RefInode(i: *Inode) void {
    if (i.isVirtual) {
        return;
    }
    @as(*Spinlock, @ptrCast(&i.lock)).acquire();
    i.refs += 1;
    @as(*Spinlock, @ptrCast(&i.lock)).release();
}

pub fn DerefInode(i: *Inode) void {
    if (i.isVirtual) {
        return;
    }
    @as(*Spinlock, @ptrCast(&i.lock)).acquire();
    if (i.refs <= 1) {
        i.refs = 0;
        if (i.destroy != null) {
            i.destroy.?(i);
        }
        if (i.parent != null) {
            const parent = i.parent.?;
            @as(*Spinlock, @ptrCast(&parent.lock)).acquire();
            RemovePhysicalInodeFromParent(i);
            @as(*Spinlock, @ptrCast(&parent.lock)).release();
            DerefInode(parent);
        }
        if (i.physChildren != null) {
            var entry = i.physChildren;
            while (entry != null) {
                entry.?.parent = null;
                entry = entry.?.nextSibling;
            }
        }
        Memory.Pool.PagedPool.Free(@as([*]u8, @ptrCast(@alignCast(i)))[0..@sizeOf(Inode)]);
        return;
    } else {
        i.refs -= 1;
    }
    @as(*Spinlock, @ptrCast(&i.lock)).release();
}

pub fn GetInode(path: []const u8, base: *Inode) ?*Inode {
    var curNode: ?*Inode = if (std.mem.startsWith(u8, path, "/")) rootInode else base;
    RefInode(curNode.?);
    var iter = std.mem.split(u8, path, "/");
    while (iter.next()) |name| {
        if (std.mem.eql(u8, name, "..")) {
            const old = curNode.?;
            curNode = curNode.?.parent;
            DerefInode(old);
        } else if (name.len == 0 or std.mem.eql(u8, name, ".")) {
            continue;
        } else {
            const lock = @as(*Spinlock, @ptrCast(&curNode.?.lock));
            var oldNode = curNode.?;
            const old = HAL.Arch.IRQEnableDisable(false);
            lock.acquire();
            curNode = FindDir(curNode.?, name);
            lock.release();
            if (curNode != null) {
                RefInode(curNode.?);
                if (!curNode.?.isVirtual and curNode.?.parent == null) {
                    curNode.?.parent = oldNode;
                    @as(*Spinlock, @ptrCast(&oldNode.lock)).acquire();
                    AddPhysicalInodeToParent(curNode.?);
                    @as(*Spinlock, @ptrCast(&oldNode.lock)).release();
                }
            }
            _ = HAL.Arch.IRQEnableDisable(old);
        }
        if (curNode == null) {
            break;
        }
    }
    if (curNode != null) {
        if (!curNode.?.isVirtual) {
            @as(*Spinlock, @ptrCast(&curNode.?.lock)).acquire();
            curNode.?.refs -= 1;
            @as(*Spinlock, @ptrCast(&curNode.?.lock)).release();
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
    const result = newFS.mount(newFS);
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
    rootInode.?.physChildren = null;
    rootInode.?.nextSibling = null;
    rootInode.?.prevSibling = null;
    rootInode.?.isVirtual = true;
    _ = NewDirInode("dev");
    DevFS.Init();
    MesgFS.Init();
}
