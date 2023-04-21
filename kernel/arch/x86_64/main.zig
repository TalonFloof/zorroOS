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
    try writer.print(level.asText() ++ " -> " ++ format ++ "\n", args);
}

pub fn earlyInitialize() void {}
