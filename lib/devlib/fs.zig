pub const Metadata = extern struct {
    deviceID: u64 = 0,
    ID: i64 = -2, // if <0 then an error occured
    mode: i32 = 0,
    nlinks: i32 = 0,
    uid: u32 = 1,
    gid: u32 = 1,
    rdev: u64 = 0, // Device ID (Optional)
    size: i64 = 0,
    atime: i64 = 0,
    reserved1: u64 = 0,
    mtime: i64 = 0,
    reserved2: u64 = 0,
    ctime: i64 = 0,
    reserved3: u64 = 0,
    blksize: i64 = 0,
    blocks: i64 = 0,
};

pub const FCB = extern struct {
    file: ?*void = null,
    mount: ?*Mountpoint = null,
    path: [*c]u8 = null,
    offset: i64,
    mode: usize,
    isDir: bool,
};

fn stub1(mount: *Mountpoint) callconv(.C) void {
    _ = mount;
}

fn stub2(mount: *Mountpoint, path: [*c]const u8, mode: usize) callconv(.C) ?*FCB {
    _ = mode;
    _ = path;
    _ = mount;
    return null;
}

fn stub3() callconv(.C) i64 {
    return -38;
}

fn stub4(mount: *Mountpoint, path: [*c]const u8) callconv(.C) Metadata {
    _ = path;
    _ = mount;
    return Metadata{ .ID = -38 };
}

pub const Mountpoint = extern struct {
    path: [*c]const u8,
    device: [*c]const u8 = null,
    data: ?*void = null,

    mount: *const fn (*Mountpoint) callconv(.C) void = &stub1,
    umount: *const fn (*Mountpoint) callconv(.C) void = &stub1,
    open: *const fn (*Mountpoint, [*c]const u8, usize) callconv(.C) ?*FCB = &stub2,
    close: *const fn (*FCB) callconv(.C) i64 = @ptrCast(*const fn (*FCB) callconv(.C) i64, &stub3),
    read: *const fn (*FCB, *void, i64) callconv(.C) i64 = @ptrCast(*const fn (*FCB, *void, i64) callconv(.C) i64, &stub3),
    readDir: *const fn (*FCB, *void) callconv(.C) i64 = @ptrCast(*const fn (*FCB, *void) callconv(.C) i64, &stub3),
    write: *const fn (*FCB, *void, i64) callconv(.C) i64 = @ptrCast(*const fn (*FCB, *void, i64) callconv(.C) i64, &stub3),
    ioctl: *const fn (*FCB, usize, *void, *c_int) callconv(.C) i64 = @ptrCast(*const fn (*FCB, usize, *void, *c_int) callconv(.C) i64, &stub3),
    map: *const fn (*FCB, *allowzero void, usize) callconv(.C) i64 = @ptrCast(*const fn (*FCB, *allowzero void, usize) callconv(.C) i64, &stub3),
    mkdir: *const fn (*Mountpoint, [*c]const u8) callconv(.C) i64 = @ptrCast(*const fn (*Mountpoint, [*c]const u8) callconv(.C) i64, &stub3),
    unlink: *const fn (*Mountpoint, [*c]const u8) callconv(.C) i64 = @ptrCast(*const fn (*Mountpoint, [*c]const u8) callconv(.C) i64, &stub3),
    stat: *const fn (*Mountpoint, [*c]const u8) callconv(.C) Metadata = &stub4,
    chown: *const fn (*Mountpoint, [*c]const u8, u32, u32) callconv(.C) i64 = @ptrCast(*const fn (*Mountpoint, [*c]const u8, u32, u32) callconv(.C) i64, &stub3),
    chmod: *const fn (*Mountpoint, [*c]const u8, usize) callconv(.C) i64 = @ptrCast(*const fn (*Mountpoint, [*c]const u8, usize) callconv(.C) i64, &stub3),
};
