const acpi = @import("acpi.zig");
const io = @import("io.zig");
const std = @import("std");
const native = @import("main.zig");
const hart = @import("hart.zig");

var lapic_ptr: usize = 0;

pub fn setup() void {
    native.wrmsr(0x1b, (native.rdmsr(0x1b) | 0x800) & ~(@as(u64, 1) << @as(u64, 10))); // Enable the Local APIC
    lapic_ptr = (native.rdmsr(0x1b) & 0xfffff000) + 0xffff800000000000; // Get the Pointer
    write(0x320, 0x10000);
    write(0xf0, 0x1f0); // Enable Spurious Interrupts (This starts up the Local APIC)
    // Next, we need to calibrate and enable the Local APIC Timer
    // (Note: The HPET can sometimes be less accurate than the PIT depending on the clock speed of the HPET.
    //        This is usually the base clock speed of the CPU, which when calculating the amount of cycles which 10 ms
    //        has passed can be less accure due to it not evenly dividing. The PIT on the other hand is guarenteed
    //        to closely hit 10 ms, though it does fall ~1 second behind/ahead per day (I think???))
    write(0x3e0, 0x3); // Set the timer to use divider 16
    // Prepare the HPET timer to wait for 10 ms
    var addr: usize = acpi.HPETAddr.?.address;
    const hpetAddr: [*]align(1) volatile u64 = @intToPtr([*]align(1) volatile u64, addr);
    var clock = hpetAddr[0] >> 32;
    hpetAddr[2] = 0;
    hpetAddr[32] = (hpetAddr[32] | (1 << 6)) & (~@intCast(u64, 0b100));
    hpetAddr[30] = 0;
    hpetAddr[2] = 1;
    const hz = @intCast(u64, 1000000000000000) / clock;
    var interval = (10 * (1000000000000 / clock));
    const val = (((hz << 16) / (interval)));
    if (hart.getHart().id == 0) {
        std.log.info("LAPICTimer: HPET @ {d} Hz (~{d}.{d} Hz interval) for calibration", .{ hz, val >> 16, (10000 * (val & 0xFFFF)) >> 16 });
    }
    write(0x380, 0xffffffff); // Set the Initial Count to 0xffffffff
    // Start the HPET or PIT timer and wait for it to finish counting down.
    const duration = hpetAddr[30] + interval;
    while (hpetAddr[30] < duration) {
        std.atomic.spinLoopHint();
    }
    write(0x320, 0x10000); // Stop the Local APIC Timer
    var ticks: u32 = 0xffffffff - read(0x390); // We now have the number of ticks that elapses in 10 ms (with divider 16 of course)
    // Set the Local APIC timer to Periodic Mode, Divider 16, and to trigger every millisecond.
    write(0x3e0, 0x3);
    write(0x380, ticks / 10);
    write(0x320, 32 | 0x20000);
    // Now, we'll start to recieve interrupts from the timer!
    // This is vital for preemptive multitasking, and will be super useful for the microkernel.
}

pub fn read(reg: usize) u32 {
    return @intToPtr(*volatile u32, lapic_ptr + reg).*;
}

pub fn write(reg: usize, val: u32) void {
    @intToPtr(*volatile u32, lapic_ptr + reg).* = val;
}

pub fn sendIpi(
    id: usize,
    vec: u8,
) void {
    _ = id;
    _ = vec;
}
