const std = @import("std");
const gdt = @import("gdt.zig");
const genhart = @import("root").hart;
const HardwareThread = @import("root").hart.HardwareThread;
const native = @import("main.zig");
const limine = @import("limine");
const alloc = @import("root").alloc;

export var smp_request: limine.SmpRequest = .{};
pub var hartData: usize = 0;

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
        genhart.hartList = @ptrCast([*]*HardwareThread, @alignCast(@sizeOf(usize), alloc.alloc(smp_response.cpu_count * @sizeOf(usize), @sizeOf(usize))))[0..smp_response.cpu_count];
        genhart.hartList.?[0] = &hart0;
        for (smp_response.cpus()) |hart| {
            if (hart.processor_id != 0) {
                var dat: *HardwareThread = @ptrCast(*HardwareThread, @alignCast(@sizeOf(usize), alloc.alloc(4096, 4096).ptr));
                genhart.hartList.?[hart.processor_id] = dat;
                dat.id = hart.processor_id;
                dat.archData.apicID = hart.lapic_id;
                dat.threadLock = .unaquired;
                dat.threadHead = null;
                dat.threadTail = null;
                dat.threadCurrent = null;
                dat.archData.tss.rsp[0] = @ptrToInt(dat) + 3072;
                hartData = @ptrToInt(dat);
                hart.goto_address = native.hartStart;
                while (hartData != 0) {
                    std.atomic.spinLoopHint();
                }
            }
        }
    }
}
