pub const Status = enum(c_int) {
    Okay = 0,
    Failure = 1,
    NoAvailableDevice = 2, // Not an error but tells the kernel to unload the driver.
};

pub const RyuDispatch = extern struct {
    put: *const fn ([*:0]const u8) callconv(.C) void,
    abort: *const fn ([*:0]const u8) callconv(.C) noreturn,
};

pub const RyuDriverInfo = extern struct {
    apiMinor: u16,
    apiMajor: u16,
    prev: ?*RyuDriverInfo = null,
    next: ?*RyuDriverInfo = null,
    baseAddr: usize = 0,
    baseSize: usize = 0,
    flags: u64 = 0,

    drvName: [*c]const u8,
    krnlDispatch: ?*const RyuDispatch = null,
    loadFn: *const fn () callconv(.C) Status,
    unloadFn: *const fn () callconv(.C) Status,
};
