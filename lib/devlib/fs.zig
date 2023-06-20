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

pub const Inode = extern struct {
    stat: Metadata = Metadata{ .ID = 0 },
    private: *allowzero void = @intToPtr(*allowzero void, 0),
    parent: ?*Inode = null,
    children: ?*Inode = null,
    nextSibling: ?*Inode = null,
    mountOwner: ?*Inode = null,
    mountPoint: ?*Inode = null,

    open: ?*const fn (*Inode, usize) callconv(.C) isize = null,
    close: ?*const fn (*Inode) callconv(.C) void = null,
    read: ?*const fn (*Inode, isize, *void, isize) callconv(.C) isize = null,
    readdir: ?*const fn (*Inode, isize) callconv(.C) ?*Inode = null,
    finddir: ?*const fn (*Inode, [*c]const u8) callconv(.C) ?*Inode = null,
    write: ?*const fn (*Inode, isize, *void, isize) callconv(.C) isize = null,
    unlink: ?*const fn (*Inode) callconv(.C) isize = null,
    ioctl: ?*const fn (*Inode, usize, *void) callconv(.C) isize = null,
    create: ?*const fn (*Inode, [*c]const u8, usize) callconv(.C) isize = null,
    map: ?*const fn (*Inode, isize, *allowzero void, usize) callconv(.C) isize = null,
    unmap: ?*const fn (*Inode, *allowzero void, usize) callconv(.C) isize = null,
};

pub const DirEntry = extern struct {};
