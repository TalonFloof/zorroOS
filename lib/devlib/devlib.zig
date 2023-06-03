pub const Status = enum(c_int) {
    Okay = 0,
    Failure = 1,
    NoAvailableDevice = 2, // Not an error but tells the kernel to unload the driver.
};

pub const RyuDispatch = extern struct {
    // Basic
    put: *const fn ([*:0]const u8) callconv(.C) void,
    abort: *const fn ([*:0]const u8) callconv(.C) noreturn,
};

pub const DriverDispatch = extern struct {};

pub const RyuDriverInfo = extern struct {
    apiMinor: u16,
    apiMajor: u16,
    prev: ?*RyuDriverInfo = null,
    next: ?*RyuDriverInfo = null,
    baseAddr: usize = 0,
    baseSize: usize = 0,
    flags: u64 = 0,

    drvName: [*c]const u8,
    drvDispatch: ?*const DriverDispatch = null,
    krnlDispatch: ?*const RyuDispatch = null,
    loadFn: *const fn () callconv(.C) Status,
    unloadFn: *const fn () callconv(.C) Status,
};

pub const RyuDeviceInfo = extern struct {
    devName: [*c]const u8,
};

pub const DPC = extern struct {
    next: ?*DPC = null,
    func: ?*const fn (u64, u64) callconv(.C) void = null,
    context1: u64 = 0,
    context2: u64 = 0,
};
