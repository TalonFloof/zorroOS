const HAL = @import("HAL.zig");
const Drivers = @import("root").Drivers;
const std = @import("std");
const builtin = @import("builtin");

pub const CrashCode = enum(u32) {
    RyuUnknownCrash = 0,
    RyuUnknownException,
    RyuNoRootFilesystem,
    RyuHALInitializationFailure,
    RyuKernelInitializationFailure,
    RyuPFNCorruption,
    RyuNoACPI,
    RyuStaticPoolDepleated,
    RyuIRQLDemoteWhilePromoting,
    RyuIRQLPromoteWhileDemoting,
    RyuPageFaultInStaticPool,
    RyuPageFaultInPagedPool,
    RyuPageFaultWhileIRQLGreaterThanUserDispatch,
    RyuUnhandledPageFault,
    RyuUnalignedAccess,
    RyuIllegalOpcode,
    RyuProtectionFault,
    RyuDoubleFault,
    RyuDeadlock,
    RyuZigPanic,
    RyuDriverAbort,
    RyuIntentionallyTriggeredFailure = 0xdeaddead,
};

pub fn Crash(code: CrashCode, args: [4]usize) noreturn {
    _ = HAL.Arch.IRQEnableDisable(false);
    HAL.Arch.Halt();
    if (builtin.mode != .Debug) {
        HAL.Console.bgColor = 0x471a7d;
        HAL.Console.showCursor = false;
        //HAL.Console.info.set(HAL.Console.info, 0, 0, HAL.Console.info.width, HAL.Console.info.height, HAL.Console.bgColor);
        HAL.Console.EnableDisable(false);
    }
    HAL.Console.EnableDisable(true);
    HAL.Console.Put("System Failure: hart={d}; code={x:0>8} {s}\n({x:0>16},{x:0>16},{x:0>16},{x:0>16})\n\n", .{
        HAL.Arch.GetHCB().hartID,
        @enumToInt(code),
        @tagName(code),
        args[0],
        args[1],
        args[2],
        args[3],
    });
    if (builtin.mode == .Debug) {
        if (Drivers.drvrHead != null) {
            var driver = Drivers.drvrHead;
            HAL.Console.Put("Driver Name      Driver Address\n", .{});
            var i: usize = 0;
            while (driver != null) {
                i = (i + 1) % 2;
                var str = driver.?.drvName[0..std.mem.len(driver.?.drvName)];
                HAL.Console.Put("{s: <16} {x:0>16}", .{ str, driver.?.baseAddr });
                if (i == 0) {
                    HAL.Console.Put("\n", .{});
                } else {
                    HAL.Console.Put(" ", .{});
                }
                driver = driver.?.next;
            }
            if (i != 0) {
                HAL.Console.Put("\n", .{});
            }
            HAL.Console.Put("\n", .{});
        }
        HAL.Console.Put("Stack Backtrace:\n", .{});
        const frameStart = @returnAddress();
        var it = std.debug.StackIterator.init(frameStart, null);
        while (it.next()) |frame| {
            if (frame == 0) {
                break;
            }
            HAL.Console.Put("0x{x:0>16} ", .{frame});
        }
        HAL.Console.Put("\n", .{});
        HAL.Debug.EnterDebugger();
    } else {
        HAL.Console.Put("An error occured that if the system were to continue, could lead to system instability or hardware damage.\n", .{});
        HAL.Console.Put("To prevent damage, your system has now been shutdown.\nAny unsaved work is lost and disks may contain corrupted data.\n", .{});
        HAL.Console.Put("\nIf you've never seen the error at the top of the screen, reboot your system by holding down the power button until it\n", .{});
        HAL.Console.Put("turns off, wait a few seconds, and then press it again. You can also use the reboot button if available.\n\n", .{});
        HAL.Console.Put("If this error continues, boot the operating system in Rescue Mode, which will only use essental drivers.\n", .{});
        HAL.Console.Put("This will allow you to attempt to diagnose the problem or isolate a faulty driver.\n", .{});
        HAL.Console.Put("If you are unable to diagnose the problem, it is recommended that you open a GitHub issue at:\nhttps://github.com/TalonFox/zorroOS\n", .{});
        HAL.Console.Put("\n(Press SysRq to open the Ryu Kernel Debugger)", .{});
        while (true) {
            HAL.Arch.WaitForIRQ();
        }
    }
    unreachable;
}
