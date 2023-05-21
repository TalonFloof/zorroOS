pub const Console = @import("HALConsole.zig");
pub const Crash = @import("HALCrash.zig");
pub const Arch = @import("x86_64/main.zig");
pub const root = @import("root");

pub export fn HALPreformStartup(stackTop: usize) callconv(.C) noreturn {
    _ = stackTop;
    Arch.PreformStartup();
    root.RyuInit();
}
