const std = @import("std");
const limine = @import("limine");
const gdt = @import("gdt.zig");
const idt = @import("idt.zig");
const physmem = @import("physmem.zig");
const root = @import("root");
const acpi = @import("acpi.zig");
const syscall = @import("syscall.zig");

pub const hart = @import("hart.zig");
pub const context = @import("context.zig");
pub const vmm = @import("vmm.zig");

export var console_request: limine.TerminalRequest = .{};

fn limineWriteString(_: @TypeOf(.{}), string: []const u8) error{}!usize {
    if (console_request.response) |console_response| {
        console_response.write(console_response.terminals()[0], string);
        return string.len;
    }
    return 0;
}

pub const Writer = std.io.Writer(@TypeOf(.{}), error{}, limineWriteString);

pub noinline fn earlyInitialize() void {
    hart.initialize0();
    gdt.initialize();
    idt.initialize();
}

pub noinline fn initialize() void {
    physmem.initialize();
    acpi.initialize();
    syscall.initialize();
    hart.startSMP();
}

pub noinline fn hartStart(d: *limine.SmpInfo) callconv(.C) noreturn {
    _ = d;
    wrmsr(0xC0000102, hart.hartData);
    gdt.initialize();
    idt.fastInit();
    syscall.initialize();
    std.log.info("hart{d:0>3}(0x{x:0>16}): ready", .{ hart.getHart().id, hart.hartData });
    hart.hartData = 0;
    while (true) {
        enableDisableInt(false);
        halt();
    }
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
