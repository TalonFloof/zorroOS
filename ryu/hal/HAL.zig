pub const Console = @import("HALConsole.zig");
pub const Crash = @import("HALCrash.zig");
pub const Arch = @import("x86_64/main.zig");
pub const Debug = @import("debug/HALDebug.zig");
pub const Splash = @import("HALSplash.zig");
const root = @import("root");
const std = @import("std");
const builtin = @import("builtin");

pub const PTEEntry = packed struct {
    r: u1 = 0,
    w: u1 = 0,
    x: u1 = 0,
    userSupervisor: u1 = 0,
    nonCached: u1 = 0,
    writeThrough: u1 = 0,
    writeCombine: u1 = 0,
    reserved: u5 = 0,
    phys: u52 = 0,
};

pub var hcbList: ?[]*root.HCB = null;

pub export fn HALPreformStartup(stackTop: usize) callconv(.C) noreturn {
    Arch.PreformStartup(stackTop);
    root.RyuInit();
    if (builtin.cpu.arch == .x86_64) {
        Splash.UpdateStatus("Reclaiming Limine Memory...");
        Arch.mem.reclaim();
    }
    Splash.UpdateStatus("Kernel Setup Complete");
    root.Executive.Thread.startScheduler = true;
    root.Executive.Thread.Reschedule(false);
}
