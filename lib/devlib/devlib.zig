pub const Status = enum(c_int) {
    Okay = 0,
    Failure = 1,
    NoAvailableDevice = 2, // Not an error but tells the kernel to unload the driver.
};

pub const RyuDispatch = extern struct {
    put: *fn ([*c]const u8) callconv(.C) void,
    abort: *fn ([*c]const u8) void,
};

pub const RyuDriverInfo = extern struct {
    apiMinor: u16,
    apiMajor: u16,
    prev: ?*void = null,
    next: ?*void = null,
    baseAddr: usize = 0,
    drvName: [*c]const u8,
    krnlDispatch: ?*RyuDispatch = null,
    flags: u64 = 0,
};
