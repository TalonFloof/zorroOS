const std = @import("std");
const HAL = @import("hal");
const limine = @import("limine");
const framebuffer = @import("framebuffer.zig");
const mem = @import("mem.zig");
const gdt = @import("gdt.zig");

pub export fn _archstart() callconv(.Naked) noreturn {
    asm volatile (
        \\mov %rsp, %rdi
        \\jmp HALPreformStartup
    );
    unreachable;
}

pub fn PreformStartup() void {
    IRQEnableDisable(false);
    gdt.initialize();
    framebuffer.init();
    mem.init();
}

pub fn IRQEnableDisable(en: bool) void {
    if (en) {
        asm volatile ("sti");
    } else {
        asm volatile ("cli");
    }
}

pub fn Halt() noreturn {
    asm volatile ("cli");
    SendIPI(-2, .IPIHalt);
    while (true) {
        asm volatile ("cli");
        asm volatile ("hlt");
    }
}

pub inline fn WaitForIRQ() void {
    asm volatile ("hlt");
}

pub const IPIType = enum {
    IPIHalt,
    IPIReschedule,
    IPIFlushTLB,
};

pub fn SendIPI(hartID: i32, typ: IPIType) void {
    _ = typ;
    _ = hartID;
}

pub const PTEEntry = packed struct {
    r: u1 = 0,
    w: u1 = 0,
    x: u1 = 0,
    nonCached: u1 = 0,
    writeThrough: u1 = 0,
    reserved: u4 = 0,
    neededLevel: u3 = 0,
    phys: u52 = 0,
};

pub inline fn GetPTELevels() usize {
    return 4;
}
