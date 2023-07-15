pub const Metadata = extern struct {
    deviceID: u64 = 0,
    ID: i64 = 0,
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

pub const DirEntry = extern struct {
    inodeID: i64 = 0,
    mode: i32 = 0,
    nameLen: u8 = 0,
    name: [256]u8 = [_]u8{0} ** 256,
};

pub const Filesystem = extern struct {
    root: *Inode,
    dev: ?*Inode,
    private: *allowzero void,
    mount: *const fn (*Filesystem) callconv(.C) bool,
    umount: *const fn (*Filesystem) callconv(.C) void,
};

pub const Inode = extern struct {
    name: [256]u8 = [_]u8{0} ** 256,
    stat: Metadata = Metadata{ .ID = 0 },
    private: *allowzero void = @as(*allowzero void, @ptrFromInt(0)),
    parent: ?*Inode = null,
    physChildren: ?*Inode = null,
    children: ?*Inode = null,
    prevSibling: ?*Inode = null,
    nextSibling: ?*Inode = null,
    mountOwner: ?*Filesystem = null,
    mountPoint: ?*Filesystem = null,
    isVirtual: bool = false,
    virtualChildren: usize = 0,
    refs: usize = 0,
    lock: u8 = 0,

    open: ?*const fn (*Inode, usize) callconv(.C) isize = null,
    close: ?*const fn (*Inode) callconv(.C) void = null,
    read: ?*const fn (*Inode, isize, *void, isize) callconv(.C) isize = null,
    readdir: ?*const fn (*Inode, usize, *DirEntry) callconv(.C) isize = null,
    finddir: ?*const fn (*Inode, [*c]const u8, usize) callconv(.C) ?*Inode = null,
    write: ?*const fn (*Inode, isize, *void, isize) callconv(.C) isize = null,
    trunc: ?*const fn (*Inode, isize) callconv(.C) isize = null,
    unlink: ?*const fn (*Inode) callconv(.C) isize = null,
    ioctl: ?*const fn (*Inode, usize, *allowzero void) callconv(.C) isize = null,
    create: ?*const fn (*Inode, [*c]const u8, usize) callconv(.C) isize = null,
    map: ?*const fn (*Inode, isize, *allowzero void, usize) callconv(.C) isize = null,
    unmap: ?*const fn (*Inode, *allowzero void, usize) callconv(.C) isize = null,

    destroy: ?*const fn (*Inode) callconv(.C) void = null, // Called when a physical inode is about to be destroyed
};
