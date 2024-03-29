const HCB = @import("root").HCB;
const HAL = @import("root").HAL;
const limine = @import("limine");
const Memory = @import("root").Memory;
const IRQL = @import("root").IRQL;
const std = @import("std");

export var smp_request: limine.SmpRequest = .{ .flags = 0 };
pub var hartData: usize = 0;

var zeroHCB: HCB = .{};

pub fn initialize(stack: usize) void {
    HAL.Arch.wrmsr(0xC0000102, @intFromPtr(&zeroHCB));
    zeroHCB.archData.tss.rsp[0] = stack;
    zeroHCB.activeIstack = stack;
    if (smp_request.response) |response| {
        zeroHCB.archData.apicID = response.bsp_lapic_id;
    }
}

pub fn startSMP() void {
    if (smp_request.response) |response| {
        HAL.hcbList = @as([*]*HCB, @ptrCast(@alignCast(Memory.Pool.StaticPool.Alloc(response.cpu_count * @sizeOf(usize)).?.ptr)))[0..response.cpu_count];
        HAL.hcbList.?[0] = &zeroHCB;
        HAL.Console.Put("{} Hart System (MultiHart Kernel)\n", .{HAL.hcbList.?.len});
        var hartCount: i32 = 1;
        for (response.cpus()) |hart| {
            if (hart.lapic_id != response.bsp_lapic_id) {
                var hcb: *HCB = @as(*HCB, @ptrCast(@alignCast(Memory.Pool.StaticPool.Alloc(@sizeOf(HCB)).?.ptr)));
                HAL.hcbList.?[@as(usize, @intCast(hartCount))] = hcb;
                hcb.hartID = hartCount;
                hcb.archData.apicID = hart.lapic_id;
                hartData = @intFromPtr(hcb);
                @as(*align(1) u64, @ptrFromInt(@intFromPtr(hart) + @offsetOf(limine.SmpInfo, "goto_address"))).* = @intFromPtr(&HAL.Arch._hartstart);
                var cycles: usize = 0;
                while (hartData != 0) {
                    cycles += 1;
                    if (cycles >= 50000000) {
                        HAL.Console.Put("Hart #{} took too long (potential triple fault on hart!)\n", .{hartCount});
                        HAL.Crash.Crash(.RyuHALInitializationFailure, .{ 0x808600000001dead, @as(usize, @intCast(hartCount)), 0, 0 }, null);
                    }
                    std.atomic.spinLoopHint();
                }
                hartCount += 1;
            }
        }
    }
}
