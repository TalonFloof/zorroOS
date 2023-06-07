pub const io = @import("io.zig");

pub const Status = enum(c_int) {
    Okay = 0,
    Failure = 1,
    NoAvailableDevice = 2, // Not an error but tells the kernel to unload the driver.
};

pub const RyuDispatch = extern struct {
    // Basic
    put: *const fn ([*:0]const u8) callconv(.C) void,
    abort: *const fn ([*:0]const u8) callconv(.C) noreturn,
    // Memory
    staticAlloc: *const fn (usize) callconv(.C) *void,
    staticAllocAnon: *const fn (usize) callconv(.C) *void,
    staticFree: *const fn (*void, usize) callconv(.C) void,
    staticFreeAnon: *const fn (*void, usize) callconv(.C) void,
    pagedAlloc: *const fn (usize) callconv(.C) *void,
    pagedAllocAnon: *const fn (usize) callconv(.C) *void,
    pagedFree: *const fn (*void, usize) callconv(.C) void,
    pagedFreeAnon: *const fn (*void, usize) callconv(.C) void,
    // IRQ
    enableDisableIRQ: *const fn (bool) callconv(.C) bool,
    attachDetatchIRQ: *const fn (u16, ?*const fn () callconv(.C) void) callconv(.C) u16,
    // Compositor
    updateMouse: *const fn (isize, isize, isize, u8) callconv(.C) void,
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
    exportedDispatch: ?*void,
    krnlDispatch: ?*const RyuDispatch = null,
    loadFn: *const fn () callconv(.C) Status,
    unloadFn: *const fn () callconv(.C) Status,
};

pub const RyuDeviceInfo = extern struct {
    devName: [*c]const u8,
};
