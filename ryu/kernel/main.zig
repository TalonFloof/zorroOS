pub const HAL = @import("hal");
pub const Memory = @import("memory");
pub const Executive = @import("executive");
pub const Spinlock = @import("Spinlock.zig").Spinlock;
pub const HCB = @import("HCB.zig").HCB;
pub const ELF = @import("ELF.zig");
pub const Drivers = @import("Drivers.zig");
pub const KernelSettings = @import("KernelSettings.zig");
pub const AATree = @import("AATree.zig").AATree;
pub const FS = @import("fs");
const std = @import("std");
const builtin = @import("builtin");

pub fn panic(msg: []const u8, stacktrace: ?*std.builtin.StackTrace, wat: ?usize) noreturn {
    _ = wat;
    _ = stacktrace;
    HAL.Console.EnableDisable(true);
    HAL.Console.Put("Fatal Zig Error: {s}\n", .{msg});
    HAL.Crash.Crash(.RyuZigPanic, .{ 0, 0, 0, 0 });
}

var ramdksImage: ?[]u8 = null;

pub export fn RyuInit() noreturn {
    HAL.Splash.UpdateStatus("Setting up UNIX Filesystems...");
    FS.Init();
    HAL.Splash.UpdateStatus("Creating Kernel Team...");
    Executive.Team.Init();
    HAL.Splash.UpdateStatus("Creating Hart Idle Threads...");
    Executive.Thread.Init();
    HAL.Splash.UpdateStatus("Loading Drivers...");
    Drivers.InitDrivers();
    Executive.OSCalls.stub();
    HAL.Splash.UpdateStatus("Mounting Root Filesystem...");
    if (KernelSettings.rootFS == null) {
        HAL.Crash.Crash(.RyuNoRootFilesystem, .{ 0, 0, 0, 0 });
    } else {
        if (std.mem.eql(u8, KernelSettings.rootFS.?, "ramdks")) {
            HAL.Console.Put("Bootloader has requested a RamDisk boot\n", .{});
            if (ramdksImage) |dks| {
                FS.CpioFS.Init(dks);
            } else {
                HAL.Console.EnableDisable(true);
                HAL.Console.Put("No RamDisk was given by the bootloader even though we're suppost to mount one as root?!\n\nSystem Halted ", .{});
                _ = HAL.Arch.IRQEnableDisable(false);
                while (true) {
                    HAL.Arch.WaitForIRQ();
                }
            }
        }
    }
    HAL.Splash.UpdateStatus("zorroOS Init Team");
    var team = Executive.Team.GetTeamByID(2).?;
    HAL.Splash.UpdateStatus("Load /bin/init...");
    var entry = Executive.Team.LoadELFImage("/bin/init", team).?;
    _ = Executive.Thread.NewThread(team, @ptrCast([*]u8, @constCast("Main Thread"))[0..11], entry, 0x9ff8, 8);
    HAL.Splash.UpdateStatus("Kernel Setup Complete");
    Executive.Thread.startScheduler = true;
    Executive.Thread.Reschedule(false);
}

pub inline fn LoadModule(name: []const u8, data: []u8) void {
    if (std.mem.eql(u8, name, "Ramdisk")) {
        ramdksImage = data;
    } else {
        Drivers.LoadDriver(name, @ptrCast(*void, data.ptr));
    }
}
