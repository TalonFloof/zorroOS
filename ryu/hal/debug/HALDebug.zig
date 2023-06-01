const std = @import("std");
const HAL = @import("root").HAL;
pub const PS2Keymap = @import("PS2Keymap.zig");

pub fn EnterDebugger() noreturn {
    // Prompt
    HAL.Console.Put("Welcome to the Ryu Kernel Debugger!\n\n", .{});
    while (true) {
        HAL.Console.Put("kdbg> ", .{});
        while (true) {
            const key = HAL.Arch.DebugGet();
            HAL.Console.Put("{c}", .{key});
            if (key == '\n') {
                break;
            }
        }
    }
}
