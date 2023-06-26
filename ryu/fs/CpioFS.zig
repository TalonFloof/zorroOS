const CPIOHeader = extern struct {
    magic: u16 align(1),
    dev: u16 align(1),
    ino: u16 align(1),
    mode: u16 align(1),
    uid: u16 align(1),
    gid: u16 align(1),
    nlinks: u16 align(1),
    rdev: u16 align(1),
    mtime: u32 align(1),
    nameSize: u16 align(1),
    fileSize: u32 align(1),
    // NUL-terminated Name follows this Header, file data follows the name.
};

pub fn Init(image: []u8) void {
    _ = image;
}
