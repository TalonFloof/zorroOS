const Memory = @import("root").Memory;
pub const Metadata = @import("devlib").fs.Metadata;
pub const Mountpoint = @import("devlib").fs.Mountpoint;
pub const File = @import("devlib").fs.File;
pub const FCB = @import("devlib").fs.FCB;
const Spinlock = @import("root").Spinlock;
const HAL = @import("root").HAL;
const std = @import("std");
const DevFS = @import("DevFS.zig");

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

pub fn Umount(path: [*c]const u8) void {
    const old = HAL.Arch.IRQEnableDisable(false);
    mountLock.acquire();
    var mount = mountHead;
    const pathA = path[0..std.mem.len(path)];
    while (mount) |mnt| {
        if (std.mem.eql(u8, pathA, mnt.mount.path[0..std.mem.len(mnt.mount.path)])) {
            mnt.mount.umount(mnt);
            if (mnt.prev) |prev| {
                prev.next = mnt.next;
            } else {
                mountHead = mnt.next;
            }
            if (mnt.next) |nxt| {
                nxt.prev = mnt.prev;
            } else {
                mountTail = mnt.prev;
            }
            break;
        }
        mount = mnt.next;
    }
    mountLock.release();
    _ = HAL.Arch.IRQEnableDisable(old);
}

pub fn Open(path: [*c]const u8, mode: usize) ?*FCB {
    var zigPath = path[0..std.mem.len(path)];
    _ = zigPath;
    var start: usize = 0;
    if (GetMountpoint(path, &start)) |mount| {
        return mount.open(mount, @intToPtr([*c]const u8, @ptrToInt(path) + start), mode);
    }
    return null;
}

pub inline fn Close(fcb: *FCB) i64 {
    return fcb.mount.?.close(fcb);
}

pub inline fn Read(fcb: *FCB, buf: []u8) i64 {
    return fcb.mount.?.read(fcb, @intToPtr(*void, @ptrToInt(buf.ptr)), @intCast(i64, buf.len));
}

pub inline fn ReadDir(fcb: *FCB, buf: *void) i64 {
    return fcb.mount.?.readDir(fcb, buf);
}

pub inline fn Write(fcb: *FCB, buf: []u8) i64 {
    return fcb.mount.?.write(fcb, @intToPtr(*void, @ptrToInt(buf.ptr)), @intCast(i64, buf.len));
}

pub fn Seek(fcb: *FCB, off: i64, whence: usize) i64 {
    if (whence == 0) { // SEEK_SET
        fcb.offset = off;
    } else if (whence == 1) { // SEEK_CUR
        fcb.offset +%= off;
    } else if (whence == 2) { // SEEK_END
        var dat = fcb.mount.?.stat(fcb.mount.?, fcb.path.?);
        if (dat.ID >= 0) {
            fcb.offset = dat.size +% off;
        } else {
            return -5; // EIO
        }
    }
    return fcb.offset;
}

pub inline fn IOCtl(fcb: *FCB, request: usize, argp: *void, argc: *c_int) i64 {
    return fcb.mount.?.ioctl(fcb, request, argp, argc);
}

pub fn Map(fcb: *FCB, addr: *allowzero void, len: usize) i64 {
    if (@ptrToInt(addr) == 0) {
        const old = HAL.Arch.IRQEnableDisable(false);
        var newAddr = Memory.Paging.FindFreeSpace(
            HAL.Arch.GetHCB().activeThread.?.team.addressSpace,
            0x1000,
            len,
        ).?; // sooooo i lied :3
        const ret = fcb.mount.?.map(fcb, newAddr, len);
        _ = HAL.Arch.IRQEnableDisable(old);
        return ret;
    } else {
        return fcb.mount.?.map(fcb, addr, len);
    }
}

pub fn MkDir(path: [*c]const u8) i64 {
    var zigPath = path[0..std.mem.len(path)];
    _ = zigPath;
    var start: usize = 0;
    if (GetMountpoint(path, &start)) |mount| {
        return mount.mkdir(mount, @intToPtr([*c]const u8, @ptrToInt(path) + start));
    }
    return -2; // ENOENT
}

pub fn Unlink(path: [*c]const u8) i64 {
    var zigPath = path[0..std.mem.len(path)];
    _ = zigPath;
    var start: usize = 0;
    if (GetMountpoint(path, &start)) |mount| {
        return mount.unlink(mount, @intToPtr([*c]const u8, @ptrToInt(path) + start));
    }
    return -2; // ENOENT
}

pub fn Stat(path: [*c]const u8) i64 {
    var zigPath = path[0..std.mem.len(path)];
    _ = zigPath;
    var start: usize = 0;
    if (GetMountpoint(path, &start)) |mount| {
        return mount.unlink(mount, @intToPtr([*c]const u8, @ptrToInt(path) + start));
    }
    return Metadata{}; // ENOENT
}

pub fn ChOwn(path: [*c]const u8, uid: u32, gid: u32) i64 {
    var zigPath = path[0..std.mem.len(path)];
    _ = zigPath;
    var start: usize = 0;
    if (GetMountpoint(path, &start)) |mount| {
        return mount.chown(mount, @intToPtr([*c]const u8, @ptrToInt(path) + start), uid, gid);
    }
    return -2; // ENOENT
}

pub fn ChMod(path: [*c]const u8, mode: usize) i64 {
    var zigPath = path[0..std.mem.len(path)];
    _ = zigPath;
    var start: usize = 0;
    if (GetMountpoint(path, &start)) |mount| {
        return mount.chmod(mount, @intToPtr([*c]const u8, @ptrToInt(path) + start), mode);
    }
    return -2; // ENOENT
}

pub fn Init() void {
    DevFS.Init();
}
