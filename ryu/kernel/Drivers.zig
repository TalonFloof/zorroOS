const devlib = @import("devlib");
const HAL = @import("root").HAL;
const ELF = @import("root").ELF;
const Memory = @import("root").Memory;
const Compositor = @import("root").Compositor;
const std = @import("std");

pub var drvrHead: ?*devlib.RyuDriverInfo = null;
pub var drvrTail: ?*devlib.RyuDriverInfo = null;

pub fn LoadDriver(name: []const u8, relocObj: *void) void {
    HAL.Console.Put("Loading Driver: {s}...\n", .{name});
    _ = ELF.LoadELF(relocObj, .Driver) catch |err| {
        HAL.Console.Put("Failed to Load Driver \"{s}\", Reason: {}\n", .{ name, err });
        return;
    };
    drvrTail.?.krnlDispatch = &KDriverDispatch;
    var ret = drvrTail.?.loadFn();
    if (ret == .Failure) {
        HAL.Console.Put("Warning: Driver \"{s}\" reported failure while loading!", .{name});
    }
}

pub export const KDriverDispatch = devlib.RyuDispatch{
    .put = &DriverPut,
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
    .updateMouse = &Compositor.Mouse.ProcessMouseUpdate,
};

fn DriverPut(s: [*:0]const u8) callconv(.C) void {
    HAL.Console.Put("{s}", .{s[0..std.mem.len(s)]});
}

fn DriverAbort(s: [*:0]const u8) callconv(.C) noreturn {
    HAL.Console.EnableDisable(true);
    HAL.Console.Put("DriverAbort: {s}\n", .{s[0..std.mem.len(s)]});
    HAL.Crash.Crash(.RyuDriverAbort, .{ 0, 0, 0, 0 });
}

fn DriverStaticAlloc(n: usize) callconv(.C) *void {
    return @ptrCast(*void, Memory.Pool.StaticPool.Alloc(n).?.ptr);
}

fn DriverStaticAllocAnon(n: usize) callconv(.C) *void {
    return @ptrCast(*void, Memory.Pool.StaticPool.AllocAnonPages(n).?.ptr);
}

fn DriverStaticFree(p: *void, n: usize) callconv(.C) void {
    Memory.Pool.StaticPool.Free(@ptrCast([*]u8, @alignCast(1, p))[0..n]);
}

fn DriverStaticFreeAnon(p: *void, n: usize) callconv(.C) void {
    Memory.Pool.StaticPool.FreeAnonPages(@ptrCast([*]u8, @alignCast(1, p))[0..n]);
}

fn DriverPagedAlloc(n: usize) callconv(.C) *void {
    return @ptrCast(*void, Memory.Pool.PagedPool.Alloc(n).?.ptr);
}

fn DriverPagedAllocAnon(n: usize) callconv(.C) *void {
    return @ptrCast(*void, Memory.Pool.PagedPool.AllocAnonPages(n).?.ptr);
}

fn DriverPagedFree(p: *void, n: usize) callconv(.C) void {
    Memory.Pool.PagedPool.Free(@ptrCast([*]u8, @alignCast(1, p))[0..n]);
}

fn DriverPagedFreeAnon(p: *void, n: usize) callconv(.C) void {
    Memory.Pool.PagedPool.FreeAnonPages(@ptrCast([*]u8, @alignCast(1, p))[0..n]);
}

fn DriverAttachDetatchIRQ(irq: u16, routine: ?*const fn () callconv(.C) void) callconv(.C) u16 {
    if (irq == 65535) {
        var i: usize = HAL.Arch.irqSearchStart;
        while (i < HAL.Arch.irqISRs.len) : (i += 1) {
            if (HAL.Arch.irqISRs[i] == null) {
                HAL.Arch.irqISRs[i] = routine;
                return @intCast(u16, i & 0xFFFF);
            }
        }
        return 0xffff;
    } else {
        HAL.Arch.irqISRs[irq] = routine;
        return irq;
    }
}
