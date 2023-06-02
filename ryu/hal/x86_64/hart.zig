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
    HAL.Arch.wrmsr(0xC0000102, @ptrToInt(&zeroHCB));
    zeroHCB.archData.tss.rsp[0] = stack;
    zeroHCB.archData.tss.ist[0] = stack;
    zeroHCB.archData.tss.ist[1] = stack;
    if (smp_request.response) |response| {
        zeroHCB.archData.apicID = response.bsp_lapic_id;
    }
}

pub fn startSMP() void {
    if (smp_request.response) |response| {
        HAL.hcbList = @ptrCast([*]*HCB, @alignCast(@sizeOf(usize), Memory.Pool.StaticPool.Alloc(response.cpu_count * @sizeOf(usize)).?.ptr))[0..response.cpu_count];
        HAL.hcbList.?[0] = &zeroHCB;
        HAL.Console.Put("{} Hart System (MultiHart Kernel)\n", .{HAL.hcbList.?.len});
        var hartCount: i32 = 1;
        for (response.cpus()) |hart| {
            if (hart.lapic_id != response.bsp_lapic_id) {
                var hcb: *HCB = @ptrCast(*HCB, @alignCast(@sizeOf(usize), Memory.Pool.StaticPool.Alloc(@sizeOf(HCB)).?.ptr));
                HAL.hcbList.?[@intCast(usize, hartCount)] = hcb;
                hcb.hartID = hartCount;
                hcb.archData.apicID = hart.lapic_id;
                hcb.currentIRQL = .IRQL_LOW;
                hcb.pendingSoftInts = 0;
                hcb.pendingSoftIntFirst = [8]?*const fn () callconv(.C) void{
                    null,
                    null,
                    null, // TODO: Add User Dispatching
                    null, // TODO: Add User Dispatching
                    &IRQL.KDCSoftInt,
                    &IRQL.KDCSoftInt,
                    &IRQL.KDCSoftInt,
                    &IRQL.KDCSoftInt,
                };
                hartData = @ptrToInt(hcb);
                @intToPtr(*align(1) u64, @ptrToInt(hart) + @offsetOf(limine.SmpInfo, "goto_address")).* = @ptrToInt(&HAL.Arch._hartstart);
                var cycles: usize = 0;
                while (hartData != 0) {
                    cycles += 1;
                    if (cycles >= 50000000) {
                        HAL.Console.Put("Hart #{} took too long (potential triple fault on hart!)\n", .{hartCount});
                        HAL.Crash.Crash(.RyuHALInitializationFailure, .{ 0x808600000001dead, @intCast(usize, hartCount), 0, 0 });
                    }
                    std.atomic.spinLoopHint();
                }
                hartCount += 1;
            }
        }
    }
}
