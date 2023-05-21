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
    RyuPageFaultWhileIRQLGreaterThanUserDispatch,
    RyuIRQLDemoteWhilePromoting,
    RyuIRQLPromoteWhileDemoting,
    RyuUnhandledPageFault,
    RyuUnalignedAccess,
    RyuIllegalOpcode,
    RyuProtectionFault,
    RyuDeadlock,
    RyuIntentionallyTriggeredFailure = 0xdeaddead,
};

pub fn Crash(code: CrashCode, args: [4]usize) noreturn {
    HAL.Console.EnableDisable(true);
    HAL.Console.Put("System Failure: hart={d} ret={x:0>16}; code={x:0>8} {s}\n({x:0>16},{x:0>16},{x:0>16},{x:0>16})\n\n", .{
        0,
        @returnAddress(),
        @enumToInt(code),
        @tagName(code),
        args[0],
        args[1],
        args[2],
        args[3],
    });
    // Begin Debugger Dump
    HAL.Console.Put("System Halted\n", .{});
    while (true) {}
}
