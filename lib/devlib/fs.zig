pub const Metadata = packed struct {
    deviceID: u64 = 0,
    ID: i64 = 0,
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

pub const Mountpoint = extern struct {};
