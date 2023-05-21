pub const HAL = @import("hal");

pub export fn RyuInit() noreturn {
    HAL.Crash.Crash(.RyuKernelInitializationFailure, .{ 0, 0, 0, 0 });
}
