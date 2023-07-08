const HAL = @import("root").HAL;
const apic = @import("apic.zig");
const io = @import("io.zig");
const Thread = @import("root").Executive.Thread;
const std = @import("std");

const Memory = @import("root").Memory;

pub fn stub() void {} // To ensure that the compiler will not optimize this module out.

pub export fn ExceptionHandler(entry: u8, con: *HAL.Arch.Context) callconv(.C) void {
    if (entry == 0x8) {
        while (true) {
            HAL.Crash.Crash(.RyuDoubleFault, .{ con.rip, con.rsp, 0, 0 }, con);
        }
    } else if (entry == 0xd and con.rip >= 0xffff800000000000) {
        HAL.Crash.Crash(.RyuProtectionFault, .{ con.rip, con.errcode, con.rsp, 0 }, con);
    } else if (entry == 0xe) {
        var addr = asm volatile ("mov %%cr2, %[ret]"
            : [ret] "={rax}" (-> usize),
        );
        const val1: usize = if (con.errcode & 2 == 0) Memory.Paging.AccessRead else Memory.Paging.AccessWrite;
        const val2: usize = if (con.errcode & 1 != 0) Memory.Paging.AccessIsValid else 0;
        const val3: usize = if (con.errcode & 4 == 0) Memory.Paging.AccessSupervisor else 0;
        const val4: usize = if (con.errcode & 16 != 0) Memory.Paging.AccessExecute else 0;
        Memory.Paging.PageFault(con.rip, addr, val1 | val2 | val3 | val4);
    } else if (entry == 0x2) {
        apic.write(0xb0, 0);
        if (HAL.Crash.hasCrashed) {
            while (HAL.Crash.hasCrashed) {
                std.atomic.spinLoopHint();
            }
        } else {
            HAL.Crash.Crash(.RyuUncorrectableHardwareError, .{ 0, 0, 0, 0 }, con);
        }
    } else if (con.rip >= 0xffff800000000000) {
        HAL.Crash.Crash(.RyuUnknownException, .{ con.rip, con.rsp, entry, con.errcode }, con);
    }
    if (con.rip < 0xffff800000000000) {
        const hcb = HAL.Arch.GetHCB();
        hcb.activeThread.?.state = .Debugging;
        hcb.activeThread.?.activeUstack = hcb.activeUstack;
        hcb.activeThread.?.context = con.*;
        hcb.activeThread.?.fcontext.Save();
        HAL.Console.Put("Userspace Exception #{} on Thread #{}\n", .{ entry, hcb.activeThread.?.threadID });
        con.Dump();
        Thread.Reschedule(false);
    }
}
pub export fn IRQHandler(entry: u8, con: *HAL.Arch.Context) callconv(.C) void {
    if (entry == 0xfd or entry == 0xf2 or entry == 0x20) { // Reschedule (either via ThreadYield, IPI, or Preemption Clock)
        if (entry != 0xfd) {
            apic.write(0xb0, 0);
        }
        Thread.Tick(con, switch (entry) {
            0x20 => 0,
            0xfd => 1,
            else => 1,
        });
    } else if (HAL.Arch.irqISRs[entry - 0x20]) |isr| {
        isr();
    }
    apic.write(0xb0, 0);
}
