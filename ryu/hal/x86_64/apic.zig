const HAL = @import("root").HAL;
const std = @import("std");
const acpi = @import("acpi.zig");

pub var lapic_ptr: usize = 0;
pub var ioapic_regSelect: *allowzero volatile u32 = @as(*allowzero volatile u32, @ptrFromInt(0));
pub var ioapic_ioWindow: *allowzero volatile u32 = @as(*allowzero volatile u32, @ptrFromInt(0));

const x2apic_register_base: usize = 0x800;

pub var ioapic_redirect: [24]u8 = .{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23 };
pub var ioapic_activelow: [24]bool = [_]bool{false} ** 24;
pub var ioapic_leveltrig: [24]bool = [_]bool{false} ** 24;
pub var hpetPeriod: usize = 0;
pub var hpetNSPeriod: usize = 0;
pub var hpetTicksPer100NS: usize = 0;
pub var hpetHZ: usize = 0;

inline fn x2apicSupport() bool {
    return (HAL.Arch.cpuid(0x1).ecx & (@as(u32, @intCast(1)) << 21)) != 0;
}

pub fn setup() void {
    if (x2apicSupport()) {
        if (HAL.Arch.GetHCB().hartID == 0) {
            lapic_ptr = 0xffffffff;
            HAL.Console.Put("X2APIC is enabled or required by system, switching to X2APIC operations\n", .{});
        }
        HAL.Arch.wrmsr(0x1b, (HAL.Arch.rdmsr(0x1b) | 0x800 | 0x400)); // Enable the X2APIC
    } else {
        HAL.Arch.wrmsr(0x1b, (HAL.Arch.rdmsr(0x1b) | 0x800) & ~(@as(u64, 1) << @as(u64, 10))); // Enable the XAPIC
        if (HAL.Arch.GetHCB().hartID == 0) {
            lapic_ptr = (HAL.Arch.rdmsr(0x1b) & 0xfffff000) + 0xffff800000000000; // Get the Pointer
        }
    }
    write(0x320, 0x10000);
    write(0xf0, 0x1f0); // Enable Spurious Interrupts (This starts up the Local APIC)
    // Next, we need to calibrate and enable the Local APIC Timer
    // (Note: The HPET can sometimes be less accurate than the PIT depending on the clock speed of the HPET.
    //        This is usually the base clock speed of the CPU, which when calculating the amount of cycles which 10 ms
    //        has passed can be less accure due to it not evenly dividing. The PIT on the other hand is guarenteed
    //        to closely hit 10 ms, though it does fall ~1 second behind/ahead per day (I think???))
    write(0x3e0, 0x3); // Set the timer to use divider 16
    // Prepare the HPET timer to wait for 10 ms
    const addr: usize = acpi.HPETAddr.?.address;
    const hpetAddr: [*]align(1) volatile u64 = @as([*]align(1) volatile u64, @ptrFromInt(addr));
    const clock = hpetAddr[0] >> 32;
    if (HAL.Arch.GetHCB().hartID == 0) {
        hpetPeriod = clock;
        hpetNSPeriod = hpetPeriod / 1000000;
        hpetTicksPer100NS = 100000000 / hpetPeriod;
        hpetAddr[2] = 0;
        hpetAddr[30] = 0;
        hpetAddr[2] = 1;
    }
    const hz = @as(u64, @intCast(1000000000000000)) / clock;
    const interval = hpetTicksPer100NS * 10000;
    const val = (((hz << 16) / (1000000000000 / clock)));
    if (HAL.Arch.GetHCB().hartID == 0) {
        HAL.Console.Put("HPET @ {d} Hz (~{d}.{d} Hz scheduler tick interval) for Local APIC Timer calibration\n", .{ hz, val >> 16, (10000 * (val & 0xFFFF)) >> 16 });
    }
    write(0x380, 0xffffffff); // Set the Initial Count to 0xffffffff
    // Start the HPET or PIT timer and wait for it to finish counting down.
    const duration = hpetAddr[30] + interval;
    while (hpetAddr[30] < duration) {
        std.atomic.spinLoopHint();
    }
    write(0x320, 0x10000); // Stop the Local APIC Timer
    const ticks: u32 = 0xffffffff - @as(u32, @intCast(read(0x390))); // We now have the number of ticks that elapses in 10 ms (with divider 16 of course)
    // Set the Local APIC timer to Periodic Mode, Divider 16, and to trigger every millisecond.
    write(0x3e0, 0x3);
    write(0x380, ticks);
    write(0x320, 32 | 0x20000);
    // Now, we'll start to recieve interrupts from the timer!
    // This is vital for preemptive multitasking, and will be super useful for the kernel.
    // Now we'll setup the IO APIC
    for (0..24) |i| {
        if (ioapic_redirect[i] != 0 and ioapic_redirect[i] != 0xff and ioapic_redirect[i] != 8) {
            const val1: u64 = if (ioapic_leveltrig[i]) @as(u64, @intCast(1)) << 15 else 0;
            const val2: u64 = if (ioapic_activelow[i]) @as(u64, @intCast(1)) << 13 else 0;
            writeIo64(0x10 + (2 * i), (ioapic_redirect[i] + 0x20) | val1 | val2);
        }
    }
}

pub fn read(reg: usize) u64 {
    if (lapic_ptr == 0xffffffff) { // X2APIC
        return HAL.Arch.rdmsr(@as(u32, @intCast(x2apic_register_base + (reg / 16))));
    } else {
        return @as(u64, @intCast(@as(*volatile u32, @ptrFromInt(lapic_ptr + reg)).*));
    }
}

pub fn write(reg: usize, val: u64) void {
    if (lapic_ptr == 0xffffffff) { // X2APIC
        HAL.Arch.wrmsr(@as(u32, @intCast(x2apic_register_base + (reg / 16))), val);
    } else {
        @as(*volatile u32, @ptrFromInt(lapic_ptr + reg)).* = @as(u32, @intCast(val & 0xFFFFFFFF));
    }
}

pub fn readIo32(reg: usize) u32 {
    ioapic_regSelect.* = @as(u32, @intCast(reg));
    return ioapic_ioWindow.*;
}

pub fn writeIo32(reg: usize, val: u32) void {
    ioapic_regSelect.* = @as(u32, @intCast(reg));
    ioapic_ioWindow.* = val;
}

pub fn readIo64(reg: usize) u64 {
    const low: u64 = @as(u64, @intCast(readIo32(reg)));
    const high: u64 = @as(u64, @intCast(readIo32(reg + 1))) << 32;
    return high | low;
}

pub fn writeIo64(reg: usize, val: u64) void {
    writeIo32(reg, @as(u32, @intCast(val & 0xFFFFFFFF)));
    writeIo32(reg + 1, @as(u32, @intCast((val >> 32) & 0xFFFFFFFF)));
}
