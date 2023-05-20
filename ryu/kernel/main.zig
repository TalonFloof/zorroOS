pub const HAL = @import("hal");

pub export fn RyuInit() noreturn {
    HAL.Crash.Crash(.RyuUnknownCrash);
}
