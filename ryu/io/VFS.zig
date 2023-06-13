const Memory = @import("root").Memory;
pub const Metadata = @import("devlib").fs.Metadata;
pub const Mountpoint = @import("devlib").fs.Mountpoint;
pub const File = @import("devlib").fs.File;
pub const FCB = @import("devlib").fs.FCB;
const Spinlock = @import("root").Spinlock;
const HAL = @import("root").HAL;
const std = @import("std");

const MountHeader = struct {
    prev: ?*MountHeader = null,
    next: ?*MountHeader = null,
    mount: *Mountpoint,
};

var mountHead: ?*MountHeader = null;
var mountTail: ?*MountHeader = null; // hehehehe, tail
var mountLock: Spinlock = .unaquired;

pub fn GetMountpoint(path: []const u8, pathStart: ?*usize) ?*Mountpoint {
    const old = HAL.Arch.IRQEnableDisable(false);
    mountLock.acquire();
    var mount = mountHead;
    var bestMount: ?*Mountpoint = null;
    var bestMountSize: usize = 0;
    while (mount) |mnt| {
        if (std.mem.eql(u8, path[0..std.mem.len(mnt.mount.path)], mnt.mount.path[0..std.mem.len(mnt.mount.path)]) and std.mem.len(mnt.mount.path) > bestMountSize) {
            bestMount = mnt.mount;
            bestMountSize = std.mem.len(mnt.mount.path);
        }
        mount = mnt.next;
    }
    mountLock.release();
    _ = HAL.Arch.IRQEnableDisable(old);
    if (pathStart) |start| {
        start.* = bestMountSize;
    }
    return bestMount;
}

pub fn Mount(mount: *Mountpoint) void {
    const old = HAL.Arch.IRQEnableDisable(false);
    mountLock.acquire();
    const header = @ptrCast(*MountHeader, @alignCast(@alignOf(MountHeader), Memory.Pool.PagedPool.Alloc(@sizeOf(MountHeader)).?.ptr));
    header.next = null;
    header.prev = mountTail;
    if (mountTail) |tail| {
        tail.next = header;
    }
    mountTail = header;
    if (mountHead == null) {
        mountHead = header;
    }
    mount.mount(mount); // ahh yes, mount mount mount :3
    mountLock.release();
    _ = HAL.Arch.IRQEnableDisable(old);
}
