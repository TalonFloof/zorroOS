const HAL = @import("HAL.zig");
const std = @import("std");

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
    HAL.Arch.IRQEnableDisable(false);
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
    HAL.Console.Put("Stack Backtrace:\n", .{});
    const frameStart = @returnAddress();
    var it = std.debug.StackIterator.init(frameStart, null);
    while (it.next()) |frame| {
        if (frame == 0) {
            break;
        }
        HAL.Console.Put("0x{x:0>16} ", .{frame});
    }
    HAL.Console.Put("\n\nSystem Halted\n", .{});
    HAL.Arch.Halt();
}
