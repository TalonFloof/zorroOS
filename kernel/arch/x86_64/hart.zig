const std = @import("std");
const gdt = @import("gdt.zig");

pub const HartData = struct {
    tss: gdt.TSS,
};
