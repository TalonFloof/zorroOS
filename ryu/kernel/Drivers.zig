const devlib = @import("devlib");
const HAL = @import("root").HAL;
const ELF = @import("root").ELF;
const Memory = @import("root").Memory;
const Spinlock = @import("root").Spinlock;
const EventQueue = @import("root").Executive.EventQueue;
const FS = @import("root").FS;
const std = @import("std");

pub var drvrHead: ?*devlib.RyuDriverInfo = null;
pub var drvrTail: ?*devlib.RyuDriverInfo = null;

pub fn LoadDriver(name: []const u8, relocObj: *void) void {
    HAL.Console.Put("Loading Driver: {s}...\n", .{name});
    _ = ELF.LoadELF(relocObj, .Driver, null) catch |err| {
        HAL.Console.Put("Failed to Load Driver \"{s}\", Reason: {}\n", .{ name, err });
        return;
    };
    drvrTail.?.krnlDispatch = &KDriverDispatch;
}

pub fn InitDrivers() void {
    HAL.Console.Put("Starting up drivers...\n", .{});
    var index = drvrHead;
    while (index) |drvr| {
        var ret = drvr.loadFn();
        if (ret == .Failure) {
            HAL.Console.Put("Warning: Driver \"{s}\" reported failure while loading!", .{drvr.drvName});
        }
        index = drvr.next;
    }
}

pub export const KDriverDispatch = devlib.RyuDispatch{
    .put = &DriverPut,
    .putRaw = &DriverPutRaw,
    .putNumber = &DriverPutNumber,
    .abort = &DriverAbort,
    .staticAlloc = &DriverStaticAlloc,
    .staticAllocAnon = &DriverStaticAllocAnon,
    .staticFree = &DriverStaticFree,
    .staticFreeAnon = &DriverStaticFreeAnon,
    .pagedAlloc = &DriverPagedAlloc,
    .pagedAllocAnon = &DriverPagedAllocAnon,
    .pagedFree = &DriverPagedFree,
    .pagedFreeAnon = &DriverPagedFreeAnon,
    .attachDetatchIRQ = &DriverAttachDetatchIRQ,
    .enableDisableIRQ = &HAL.Arch.IRQEnableDisable,
    .acquireSpinlock = &DriverAcquireSpinlock,
    .releaseSpinlock = &DriverReleaseSpinlock,
    .waitEvent = &DriverWaitEvent,
    .wakeupEvent = &DriverWakeupEvent,
    .registerDevice = &DriverRegisterDevice,
    .registerFilesystem = &DriverRegisterFilesystem,
};

fn DriverPut(s: [*c]const u8) callconv(.C) void {
    HAL.Console.Put("{s}", .{s[0..std.mem.len(s)]});
}

fn DriverPutRaw(s: [*c]u8, len: usize) callconv(.C) void {
    HAL.Console.Put("{s}", .{@as([*]u8, @ptrCast(s))[0..len]});
}

fn DriverPutNumber(n: u64, base: u8, isSigned: bool, padding: u8, width: usize) callconv(.C) void {
    var buf: [64]u8 = [_]u8{0} ** 64;
    if (isSigned) {
        const size = std.fmt.formatIntBuf(buf[0..64], @as(i64, @bitCast(n)), base, .lower, std.fmt.FormatOptions{
            .fill = padding,
            .width = if (width == 0) null else width,
            .alignment = .right,
        });
        HAL.Console.Put("{s}", .{buf[0..size]});
    } else {
        const size = std.fmt.formatIntBuf(buf[0..64], n, base, .lower, std.fmt.FormatOptions{
            .fill = padding,
            .width = if (width == 0) null else width,
            .alignment = .right,
        });
        HAL.Console.Put("{s}", .{buf[0..size]});
    }
}

fn DriverAbort(s: [*c]const u8) callconv(.C) void {
    HAL.Console.EnableDisable(true);
    HAL.Console.Put("DriverAbort: {s}\n", .{s[0..std.mem.len(s)]});
    HAL.Crash.Crash(.RyuDriverAbort, .{ 0, 0, 0, 0 }, null);
}

fn DriverStaticAlloc(n: usize) callconv(.C) *void {
    return @as(*void, @ptrCast(Memory.Pool.StaticPool.Alloc(n).?.ptr));
}

fn DriverStaticAllocAnon(n: usize) callconv(.C) *void {
    return @as(*void, @ptrCast(Memory.Pool.StaticPool.AllocAnonPages(n).?.ptr));
}

fn DriverStaticFree(p: *void, n: usize) callconv(.C) void {
    Memory.Pool.StaticPool.Free(@as([*]u8, @ptrCast(@alignCast(p)))[0..n]);
}

fn DriverStaticFreeAnon(p: *void, n: usize) callconv(.C) void {
    Memory.Pool.StaticPool.FreeAnonPages(@as([*]u8, @ptrCast(@alignCast(p)))[0..n]);
}

fn DriverPagedAlloc(n: usize) callconv(.C) *void {
    return @as(*void, @ptrCast(Memory.Pool.PagedPool.Alloc(n).?.ptr));
}

fn DriverPagedAllocAnon(n: usize) callconv(.C) *void {
    return @as(*void, @ptrCast(Memory.Pool.PagedPool.AllocAnonPages(n).?.ptr));
}

fn DriverPagedFree(p: *void, n: usize) callconv(.C) void {
    Memory.Pool.PagedPool.Free(@as([*]u8, @ptrCast(@alignCast(p)))[0..n]);
}

fn DriverPagedFreeAnon(p: *void, n: usize) callconv(.C) void {
    Memory.Pool.PagedPool.FreeAnonPages(@as([*]u8, @ptrCast(@alignCast(p)))[0..n]);
}

fn DriverAttachDetatchIRQ(irq: u16, routine: ?*const fn () callconv(.C) void) callconv(.C) u16 {
    if (irq == 65535) {
        var i: usize = HAL.Arch.irqSearchStart;
        while (i < HAL.Arch.irqISRs.len) : (i += 1) {
            if (HAL.Arch.irqISRs[i] == null) {
                HAL.Arch.irqISRs[i] = routine;
                return @as(u16, @intCast(i & 0xFFFF));
            }
        }
        return 0xffff;
    } else {
        HAL.Arch.irqISRs[irq] = routine;
        return irq;
    }
}

fn DriverAcquireSpinlock(v: *volatile u8) callconv(.C) void {
    @as(*volatile Spinlock, @ptrCast(v)).acquire();
}

fn DriverReleaseSpinlock(v: *volatile u8) callconv(.C) void {
    @as(*volatile Spinlock, @ptrCast(v)).release();
}

fn DriverWaitEvent(queue: *devlib.EventQueue) callconv(.C) usize {
    return @as(*EventQueue, @ptrCast(queue)).Wait();
}

fn DriverWakeupEvent(queue: *devlib.EventQueue, val: usize) callconv(.C) void {
    @as(*EventQueue, @ptrCast(queue)).Wakeup(val);
}

fn DriverRegisterDevice(name: [*c]const u8, inode: *FS.Inode) callconv(.C) void {
    FS.DevFS.RegisterDevice(name[0..std.mem.len(name)], inode);
}

fn DriverRegisterFilesystem(name: [*c]const u8, mount: *const fn (*FS.Filesystem) callconv(.C) bool, umount: *const fn (*FS.Filesystem) callconv(.C) void) callconv(.C) void {
    FS.RegisterFilesystem(name[0..std.mem.len(name)], mount, umount);
}
