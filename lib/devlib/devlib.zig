pub const io = @import("io.zig");
pub const fs = @import("fs.zig");
pub const EventQueue = @import("event.zig").EventQueue;
const std = @import("std");

pub const Status = enum(c_int) {
    Okay = 0,
    Failure = 1,
    NoAvailableDevice = 2, // Not an error but tells the kernel to unload the driver.
};

pub const RyuDispatch = extern struct {
    // Basic
    put: *const fn ([*c]const u8) callconv(.C) void,
    putRaw: *const fn ([*c]u8, usize) callconv(.C) void,
    putNumber: *const fn (u64, u8, bool, u8, usize) callconv(.C) void,
    abort: *const fn ([*c]const u8) callconv(.C) void,
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
    // Spinlock
    acquireSpinlock: *const fn (*volatile u8) callconv(.C) void,
    releaseSpinlock: *const fn (*volatile u8) callconv(.C) void,
    // Event
    waitEvent: *const fn (*EventQueue) callconv(.C) usize,
    wakeupEvent: *const fn (*EventQueue, usize) callconv(.C) void,
    // DevFS
    registerDevice: *const fn ([*c]const u8, *fs.Inode) callconv(.C) void,
    // Filesystem
    registerFilesystem: *const fn ([*c]const u8, *const fn (*fs.Filesystem) callconv(.C) bool, *const fn (*fs.Filesystem) callconv(.C) void) callconv(.C) void,
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

pub fn FindDriver(info: *RyuDriverInfo, name: []const u8) ?*void {
    var index = info.next;
    while (index) |drvr| {
        if (std.mem.eql(u8, @as([*]u8, @ptrCast(drvr.drvName))[0..std.mem.len(drvr.drvName)], name)) {
            return drvr.exportedDispatch;
        }
        index = drvr.next;
    }
    index = info.prev;
    while (index) |drvr| {
        if (std.mem.eql(u8, @as([*]u8, @ptrCast(drvr.drvName))[0..std.mem.len(drvr.drvName)], name)) {
            return drvr.exportedDispatch;
        }
        index = drvr.prev;
    }
    return null;
}
