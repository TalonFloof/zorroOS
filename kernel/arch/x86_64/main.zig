const std = @import("std");
const limine = @import("limine");
const gdt = @import("gdt.zig");
const idt = @import("idt.zig");
const physmem = @import("physmem.zig");
const root = @import("root");

pub const context = @import("context.zig");

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
var writerLock: root.Spinlock = root.Spinlock.unaquired;

pub fn doLog(
    comptime level: std.log.Level,
    comptime scope: @TypeOf(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    writerLock.acquire("WriterSpinlock");
    _ = scope;
    switch (level) {
        .info => {
            _ = try writer.write("\x1b[36m");
        },
        .warn => {
            _ = try writer.write("\x1b[33m");
        },
        .err => {
            _ = try writer.write("\x1b[31m");
        },
        else => {},
    }
    if (level == .debug) {
        try writer.print(format, args);
    } else {
        try writer.print(level.asText() ++ "\x1b[0m: " ++ format ++ "\n", args);
    }
    writerLock.release();
}

pub noinline fn earlyInitialize() void {
    gdt.initialize();
    idt.initialize();
}

pub noinline fn initialize() void {
    physmem.initialize();
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

// x86_64 Exclusives
pub fn rdmsr(index: u32) u64 {
    var low: u32 = 0;
    var high: u32 = 0;
    asm volatile ("rdmsr"
        : [lo] "={rax}" (low),
          [hi] "={rdx}" (high),
        : [ind] "{rcx}" (index),
    );
    return (@intCast(u64, high) << 32) | @intCast(u64, low);
}

pub fn wrmsr(index: u32, val: u64) void {
    var low: u32 = @intCast(u32, val & 0xFFFFFFFF);
    var high: u32 = @intCast(u32, val >> 32);
    asm volatile ("wrmsr"
        :
        : [lo] "{rax}" (low),
          [hi] "{rdx}" (high),
          [ind] "{rcx}" (index),
    );
}
