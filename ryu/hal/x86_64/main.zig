const std = @import("std");
const HAL = @import("root").HAL;
const limine = @import("limine");
const framebuffer = @import("framebuffer.zig");
const mem = @import("mem.zig");
const gdt = @import("gdt.zig");
const idt = @import("idt.zig");
const acpi = @import("acpi.zig");
const apic = @import("apic.zig");
const hart = @import("hart.zig");
const HCB = @import("root").HCB;

pub export fn _archstart() callconv(.Naked) noreturn {
    asm volatile (
        \\mov %rsp, %rdi
        \\jmp HALPreformStartup
    );
    unreachable;
}

pub export fn _hartstart() callconv(.Naked) noreturn {
    asm volatile (
        \\mov %rsp, %rdi
        \\jmp HartStart
    );
    unreachable;
}

pub fn PreformStartup(stackTop: usize) void {
    IRQEnableDisable(false);
    hart.initialize(stackTop);
    gdt.initialize();
    idt.initialize();
    framebuffer.init();
    mem.init();
    acpi.initialize();
    apic.setup();
    hart.startSMP();
}

pub export fn HartStart(stack: u64) callconv(.C) noreturn {
    wrmsr(0xC0000102, hart.hartData);
    GetHCB().archData.tss.rsp[0] = stack;
    GetHCB().archData.tss.ist[0] = stack;
    GetHCB().archData.tss.ist[1] = stack;
    gdt.initialize();
    apic.setup();
    idt.fastInit();
    hart.hartData = 0;
    while (true) {
        IRQEnableDisable(false);
        WaitForIRQ();
    }
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

pub fn GetHCB() *HCB {
    return @intToPtr(*HCB, rdmsr(0xC0000102));
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

const NativePTEEntry = packed struct {
    valid: u1 = 0,
    write: u1 = 0,
    user: u1 = 0,
    writeThrough: u1 = 0,
    cacheDisable: u1 = 0,
    reserved: u7 = 0,
    phys: u51 = 0,
    noExecute: u1 = 0,
};

pub fn GetPTE(root: *void, index: usize) HAL.PTEEntry {
    var entries: []align(1) NativePTEEntry = @ptrCast([*]align(1) NativePTEEntry, @alignCast(1, root))[0..512];
    var entry: HAL.PTEEntry = HAL.PTEEntry{};
    entry.r = entries[index].valid;
    entry.w = entries[index].write;
    entry.x = ~entries[index].noExecute;
    entry.nonCached = entries[index].cacheDisable;
    entry.writeThrough = entries[index].writeThrough;
    entry.phys = @intCast(u52, entries[index].phys);
    return entry;
}

pub fn SetPTE(root: *void, index: usize, entry: HAL.PTEEntry) void {
    var entries: []align(1) NativePTEEntry = @ptrCast([*]align(1) NativePTEEntry, @alignCast(1, root))[0..512];
    entries[index].valid = entry.r;
    entries[index].write = entry.w;
    entries[index].noExecute = ~entry.x;
    entries[index].cacheDisable = entry.nonCached;
    entries[index].writeThrough = entry.writeThrough;
    entries[index].phys = @intCast(u51, entry.phys & 0xfffffffff);
}

pub inline fn GetPTELevels() usize {
    return 4;
}

pub const ArchHCBData = struct {
    tss: gdt.TSS = gdt.TSS{},
    apicID: u32 = 0,
};

// x86_64 Exclusives
pub fn rdmsr(index: u32) u64 {
    var low: u32 = 0;
    var high: u32 = 0;
    asm volatile ("rdmsr"
        : [lo] "={rax}" (low),
          [hi] "={rdx}" (high),
        : [ind] "{rcx}" (index),
    );
    return (@intCast(u64, high) << 32) | @intCast(u64, low);
}

pub fn wrmsr(index: u32, val: u64) void {
    var low: u32 = @intCast(u32, val & 0xFFFFFFFF);
    var high: u32 = @intCast(u32, val >> 32);
    asm volatile ("wrmsr"
        :
        : [lo] "{rax}" (low),
          [hi] "{rdx}" (high),
          [ind] "{rcx}" (index),
    );
}
