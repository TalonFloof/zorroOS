pub const Metadata = packed struct {
    deviceID: u64 = 0,
    ID: i64 = 0, // if -1 then an error occured
    mode: i32 = 0,
    nlinks: i32 = 1,
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
    path: ?[*c]u8 = null,
    offset: i64,
    mode: usize,
    isDir: bool,
};

pub const Mountpoint = extern struct {
    path: [*c]const u8,
    device: ?[*c]const u8 = null,
    data: ?*void = null,

    mount: *const fn (*Mountpoint) callconv(.C) void,
    umount: *const fn (*Mountpoint) callconv(.C) void,
    open: *const fn (*Mountpoint, [*c]const u8, mode: usize) callconv(.C) ?*FCB,
    close: *const fn (*FCB) callconv(.C) void,
    read: *const fn (*FCB, *void, i64) callconv(.C) i64,
    write: *const fn (*FCB, *void, i64) callconv(.C) i64,
    mkdir: *const fn (*Mountpoint, [*c]const u8) callconv(.C) bool,
    unlink: *const fn (*Mountpoint, [*c]const u8) callconv(.C) bool,
    stat: *const fn (*Mountpoint, [*c]const u8) callconv(.C) Metadata,
    chown: *const fn (*Mountpoint, [*c]const u8, u32, u32) callconv(.C) bool,
    chmod: *const fn (*Mountpoint, [*c]const u8, usize) callconv(.C) void,
    ioctl: *const fn (*FCB, usize, *void, *c_int) callconv(.C) bool,
    map: *const fn (*FCB, *allowzero void, usize) callconv(.C) bool,
};
