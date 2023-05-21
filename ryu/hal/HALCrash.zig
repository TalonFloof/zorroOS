const HAL = @import("HAL.zig");
const std = @import("std");

pub const CrashCode = enum {
    RyuUnknownCrash,
    RyuUnknownException,
    RyuNoRootFilesystem,
    RyuPhase0Exception,
    RyuHALInitializationFailure,
    RyuKernelInitializationFailure,
    RyuPFNCorruption,
    RyuNoACPI,
    RyuStaticPoolDepleated,
    RyuIRQLUnexpectedLowerIRQL,
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
    HAL.Console.Put("Kernel version:\nRyu Kernel Version 0.0.1\n\nSystem Halted\n", .{});
    while (true) {}
}
