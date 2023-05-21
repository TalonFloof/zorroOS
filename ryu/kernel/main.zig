pub const HAL = @import("hal");
pub const Memory = @import("memory");

pub export fn RyuInit() noreturn {
    HAL.Crash.Crash(.RyuIntentionallyTriggeredFailure, .{ 0, 0, 0, 0 });
}
