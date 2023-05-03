const acpi = @import("acpi.zig");
const io = @import("io.zig");
const std = @import("std");
const native = @import("main.zig");

var lapic_ptr: usize = 0;

pub fn setup() void {
    native.wrmsr(0x1b, (native.rdmsr(0x1b) | 0x800) & ~(@as(u64, 1) << @as(u64, 10)));
    lapic_ptr = (native.rdmsr(0x1b) & 0xfffff000) + 0xffff800000000000;
    write(0xf0, 0x1ff);
}

pub fn read(reg: usize) u32 {
    return @intToPtr(*volatile u32, lapic_ptr + reg).*;
}

pub fn write(reg: usize, val: u32) void {
    @intToPtr(*volatile u32, lapic_ptr + reg).* = val;
}
