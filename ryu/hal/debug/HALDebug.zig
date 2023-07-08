const std = @import("std");
const HAL = @import("root").HAL;
const Memory = @import("root").Memory;
const Team = @import("root").Executive.Team;
const Thread = @import("root").Executive.Thread;
pub const PS2Keymap = @import("PS2Keymap.zig");

const DebugCommand = struct {
    next: ?*DebugCommand,
    name: []const u8,
    desc: []const u8,
    func: *const fn (cmd: []const u8, iter: *std.mem.SplitIterator(u8, .sequence)) void,
};

var cmdTail: ?*DebugCommand = null;

pub fn NewDebugCommand(name: []const u8, desc: []const u8, func: *const fn (cmd: []const u8, iter: *std.mem.SplitIterator(u8, .sequence)) void) void {
    var dbgCmd = @as(*DebugCommand, @alignCast(@ptrCast(Memory.Pool.StaticPool.Alloc(@sizeOf(DebugCommand)).?.ptr)));
    dbgCmd.name = name;
    dbgCmd.desc = desc;
    dbgCmd.func = func;
    dbgCmd.next = cmdTail;
    cmdTail = dbgCmd;
}

pub fn EnterDebugger() void {
    // Prompt
    HAL.Console.Put("Welcome to the Ryu Kernel Debugger!\n\n", .{});
    while (true) {
        HAL.Console.Put("kdbg> ", .{});
        var buf: [256]u8 = [_]u8{0} ** 256;
        var i: usize = 0;
        while (true) {
            const key = HAL.Arch.DebugGet();
            if ((key == '\n') or (key != 8 and i < 256) or (key == 8 and i > 0)) {
                HAL.Console.Put("{c}", .{key});
            }
            if (key == '\n') {
                break;
            }
            if (key == 8) {
                if (i > 0) {
                    i -= 1;
                }
            } else {
                if (i < 256) {
                    buf[i] = key;
                    i += 1;
                }
            }
        }
        const txt = buf[0..i];
        _ = txt;
        var iter = std.mem.split(u8, buf[0..i], " ");
        const cmd = iter.next().?;
        if (std.mem.eql(u8, cmd, "help")) {
            HAL.Console.Put("List of available commands:\n help - Prints a brief description of all available commands\n continue - Exits the debugger and continues execution\n", .{});
            var c = cmdTail;
            while (c != null) {
                HAL.Console.Put(" {s} - {s}\n", .{ c.?.name, c.?.desc });
                c = c.?.next;
            }
        } else if (std.mem.eql(u8, cmd, "continue")) {
            break;
        } else {
            var c = cmdTail;
            while (c != null) {
                if (std.mem.eql(u8, cmd, c.?.name)) {
                    c.?.func(cmd, &iter);
                    break;
                }
                c = c.?.next;
            }
            if (c == null) {
                HAL.Console.Put("{s}?\n", .{cmd});
            }
        }
    }
}
