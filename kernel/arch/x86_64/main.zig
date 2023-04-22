const std = @import("std");
const limine = @import("limine");
const idt = @import("idt.zig");

export var console_request: limine.TerminalRequest = .{};

fn limineWriteString(_: @TypeOf(.{}), string: []const u8) error{}!usize {
    if (console_request.response) |console_response| {
        console_response.write(console_response.terminals()[0], string);
        return string.len;
    }
    return 0;
}

const Writer = std.io.Writer(@TypeOf(.{}), error{}, limineWriteString);
const writer = Writer{ .context = .{} };

pub fn doLog(
    comptime level: std.log.Level,
    comptime scope: @TypeOf(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    _ = scope;
    switch (level) {
        .debug => {
            _ = try writer.write("\x1b[1;30m");
        },
        .info => {
            _ = try writer.write("\x1b[36m");
        },
        .warn => {
            _ = try writer.write("\x1b[33m");
        },
        .err => {
            _ = try writer.write("\x1b[31m");
        },
    }
    try writer.print(level.asText() ++ "\x1b[0m: " ++ format ++ "\n", args);
}

pub noinline fn earlyInitialize() void {
    idt.initialize();
}

pub fn enableDisableInt(enabled: bool) void {
    if (enabled) {
        asm volatile ("sti");
    } else {
        asm volatile ("cli");
    }
}

pub inline fn halt() void {
    asm volatile ("hlt");
}
