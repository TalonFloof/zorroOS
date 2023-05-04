const std = @import("std");
const gdt = @import("gdt.zig");
const genhart = @import("root").hart;
const HardwareThread = @import("root").hart.HardwareThread;
const native = @import("main.zig");
const limine = @import("limine");
const alloc = @import("root").alloc;

export var smp_request: limine.SmpRequest = .{ .flags = 0 };
pub var hartData: usize = 0;

pub const HartData = struct {
    tss: gdt.TSS,
    apicID: u32 = 0,
};

var hart0: HardwareThread = .{
    .id = 0,
    .archData = .{ .tss = gdt.TSS{} },
};

pub fn initialize0(stack: u64) void {
    native.wrmsr(0xC0000102, @ptrToInt(&hart0));
    hart0.archData.tss.rsp[0] = stack;
    hart0.archData.tss.ist[0] = stack;
    hart0.archData.tss.ist[1] = stack;
}

pub inline fn getHart() *HardwareThread {
    return @intToPtr(*HardwareThread, native.rdmsr(0xC0000102));
}

pub fn startSMP() void {
    if (smp_request.response) |smp_response| {
        genhart.hartList = @ptrCast([*]*HardwareThread, @alignCast(@sizeOf(usize), alloc.alloc(smp_response.cpu_count * @sizeOf(usize), @sizeOf(usize))))[0..smp_response.cpu_count];
        genhart.hartList.?[0] = &hart0;
        var hartCount: u32 = 1;
        for (smp_response.cpus()) |hart| {
            if (hart.lapic_id != smp_response.bsp_lapic_id) {
                var dat: *HardwareThread = @ptrCast(*HardwareThread, @alignCast(@sizeOf(usize), alloc.alloc(@sizeOf(HardwareThread), 1).ptr));
                genhart.hartList.?[hartCount] = dat;
                dat.id = hartCount;
                dat.archData.apicID = hart.lapic_id;
                hartData = @ptrToInt(dat);
                @intToPtr(*align(1) u64, @ptrToInt(hart) + @offsetOf(limine.SmpInfo, "goto_address")).* = @ptrToInt(&native._kstart);
                var cycles: usize = 0;
                while (hartData != 0) {
                    cycles += 1;
                    if (cycles >= 50000000) {
                        std.log.err("hart{d:0>3} took too long (potential triple fault on hart!)", .{hartCount});
                        @panic("Hart Initialization Failure");
                    }
                    std.atomic.spinLoopHint();
                }
                hartCount += 1;
            }
        }
    }
}
