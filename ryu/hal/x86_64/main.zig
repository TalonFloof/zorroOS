const std = @import("std");
const HAL = @import("hal");
const limine = @import("limine");
const framebuffer = @import("framebuffer.zig");
const mem = @import("mem.zig");
const gdt = @import("gdt.zig");
const idt = @import("idt.zig");

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
    idt.initialize();
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

pub const Context = packed struct {
    r15: u64 = 0,
    r14: u64 = 0,
    r13: u64 = 0,
    r12: u64 = 0,
    r11: u64 = 0,
    r10: u64 = 0,
    r9: u64 = 0,
    r8: u64 = 0,
    rbp: u64 = 0,
    rdi: u64 = 0,
    rsi: u64 = 0,
    rdx: u64 = 0,
    rcx: u64 = 0,
    rbx: u64 = 0,
    rax: u64 = 0,
    rip: u64 = 0,
    cs: u64 = 0,
    rflags: u64 = 0x202,
    rsp: u64 = 0,
    ss: u64 = 0,
};

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
