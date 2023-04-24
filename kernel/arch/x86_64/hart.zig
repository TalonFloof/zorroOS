const std = @import("std");
const gdt = @import("gdt.zig");
const HardwareThread = @import("root").hart.HardwareThread;
const native = @import("main.zig");
const limine = @import("limine");

export var smp_request: limine.SmpRequest = .{};

pub const HartData = struct {
    tss: gdt.TSS,
    apicID: u32 = 0,
};

var hart0: HardwareThread = .{
    .kstack = [_]u8{0} ** 3072,
    .id = 0,
    .archData = .{ .tss = gdt.TSS{} },
};

pub fn initialize0() void {
    native.wrmsr(0xC0000102, @ptrToInt(&hart0));
}

pub inline fn getHart() *HardwareThread {
    return @intToPtr(*HardwareThread, native.rdmsr(0xC0000102));
}

pub fn startSMP() void {
    if (smp_request.response) |smp_response| {
        for (smp_response.cpus()) |hart| {
            _ = hart;
        }
    }
}
