const std = @import("std");
const HAL = @import("root").HAL;
const limine = @import("limine");
const framebuffer = @import("framebuffer.zig");
pub const mem = @import("mem.zig");
const gdt = @import("gdt.zig");
const idt = @import("idt.zig");
const acpi = @import("acpi.zig");
const apic = @import("apic.zig");
const hart = @import("hart.zig");
const io = @import("io.zig");
const syscall = @import("syscall.zig");
const HCB = @import("root").HCB;
const IRQL = @import("root").IRQL;
const Drivers = @import("root").Drivers;
const kernel = @import("root");
const KernelSettings = @import("root").KernelSettings;
const Memory = @import("root").Memory;

export var module_request = limine.ModuleRequest{};
export var kfile_request = limine.KernelFileRequest{};
export var highhalf_request = limine.HhdmRequest{};
export var unixtime_request = limine.BootTimeRequest{};

var noNX: bool = false;

pub export fn _archstart() callconv(.Naked) noreturn {
    asm volatile (
        \\mov %rsp, %rdi
        \\jmp HALPreformStartup
    );
}

pub export fn _hartstart() callconv(.Naked) noreturn {
    asm volatile (
        \\cli
        \\mov %rsp, %rdi
        \\jmp HartStart
    );
}

extern fn ContextEnter(context: *allowzero void) callconv(.C) noreturn;
extern fn ContextSetupFPU() callconv(.C) void;
pub extern fn ThreadYield() callconv(.C) usize;

var initialUNIXTime: i64 = 0;

pub fn PreformStartup(stackTop: usize) void {
    asm volatile ("cli");
    wrmsr(0x277, 0x0107040600070406); // Enable write combining when PAT, PCD, and PWT is set
    ContextSetupFPU();
    hart.initialize(stackTop);
    gdt.initialize();
    idt.initialize();
    if (unixtime_request.response) |response| {
        initialUNIXTime = response.boot_time;
    }
    var kfstart: usize = 0;
    var kfend: usize = 0;
    if (kfile_request.response) |response| {
        KernelSettings.ParseCommandline(response.kernel_file.cmdline[0..std.mem.len(response.kernel_file.cmdline)]);
        kfstart = @intFromPtr(response.kernel_file.address) - 0xffff800000000000;
        kfend = if ((response.kernel_file.size % 4096) != 0) (kfstart + ((response.kernel_file.size / 4096 + 1) * 4096)) else (kfstart + response.kernel_file.size);
    }
    framebuffer.init();
    // Detect if NX is supported (just in case we need to warn the user ;3)
    if (cpuid(0x80000001).edx & (@as(u32, @intCast(1)) << 20) == 0) {
        HAL.Console.Put("WARNING!!!! Your CPU does not support the NX (No Execute) bit extension!\n", .{});
        HAL.Console.Put("            This allows for programs to exploit buffer overflows to run malicious code.\n", .{});
        HAL.Console.Put("            Your machine's security is at risk!\n", .{});
        noNX = true;
    }
    mem.init(kfstart, kfend);
    acpi.initialize();
    apic.setup();
    syscall.init();
    hart.startSMP();
    var index: usize = 0;
    while (index < 256) : (index += 1) {
        Memory.Paging.initialPageDir.?[index] = 0;
    }
    if (module_request.response) |response| {
        for (response.modules()) |mod| {
            const name = mod.cmdline[0..std.mem.len(mod.cmdline)];
            kernel.LoadModule(name, mod.address[0..mod.size]);
        }
    }
}

pub export fn HartStart(stack: u64) callconv(.C) noreturn {
    wrmsr(0xC0000102, hart.hartData);
    wrmsr(0x277, 0x0107040600070406); // Enable write combining when PAT, PCD, and PWT is set
    ContextSetupFPU();
    GetHCB().archData.tss.rsp[0] = stack;
    GetHCB().activeIstack = stack;
    gdt.initialize();
    apic.setup();
    idt.fastInit();
    syscall.init();
    hart.hartData = 0;
    while (!kernel.Executive.Thread.startScheduler) {
        std.atomic.spinLoopHint();
    }
    kernel.Executive.Thread.Reschedule(false);
}

pub fn IRQEnableDisable(en: bool) callconv(.C) bool {
    const old = asm volatile (
        \\pushfq
        \\popq %rax
        : [o] "={rax}" (-> u64),
    );
    if (en) {
        asm volatile ("sti");
    } else {
        asm volatile ("cli");
    }
    return old & 0x200 != 0;
}

pub fn Halt() void {
    asm volatile ("cli");
    SendIPI(-2, .IPIHalt);
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
    var ipi: u64 = switch (typ) {
        .IPIHalt => 0x4f1,
        .IPIReschedule => 0xf2,
        .IPIFlushTLB => 0xf3,
    };
    if (hartID == -1) {
        ipi |= 2 << 18;
    } else if (hartID == -2) {
        ipi |= 3 << 18;
    }
    if (apic.lapic_ptr == 0) {
        return;
    }
    if (apic.lapic_ptr == 0xffffffff) { // X2APIC
        if (hartID >= 0) {
            apic.write(0x310, @as(u64, @intCast(hartID)));
        }
    } else {
        if (hartID >= 0) {
            apic.write(0x310, (@as(u64, @intCast(hartID)) & 0xFF) << 24);
        }
    }
    apic.write(0x300, ipi);
}

pub fn GetHCB() *HCB {
    return @as(*HCB, @ptrFromInt(rdmsr(0xC0000102)));
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
    errcode: u64 = 0,
    rip: u64 = 0,
    cs: u64 = 0,
    rflags: u64 = 0x202,
    rsp: u64 = 0,
    ss: u64 = 0,

    pub fn SetMode(self: *Context, kern: bool) void {
        if (kern) {
            self.cs = 0x28;
            self.ss = 0x30;
        } else {
            self.cs = 0x43;
            self.ss = 0x3b;
        }
        self.rflags = 0x202;
    }

    pub fn SetReg(self: *Context, reg: u8, val: u64) void {
        switch (reg) {
            0 => {
                self.rax = val;
            },
            1 => {
                self.rdi = val;
            },
            2 => {
                self.rsi = val;
            },
            3 => {
                self.rdx = val;
            },
            4 => {
                self.r10 = val;
            },
            5 => {
                self.r8 = val;
            },
            6 => {
                self.r9 = val;
            },
            128 => {
                self.rip = val;
            },
            129 => {
                self.rsp = val;
            },
            else => {},
        }
    }

    pub fn GetReg(self: *Context, reg: u8) u64 {
        return switch (reg) {
            0 => self.rax,
            1 => self.rdi,
            2 => self.rsi,
            3 => self.rdx,
            4 => self.r10,
            5 => self.r8,
            6 => self.r9,
            128 => self.rip,
            129 => self.rsp,
            else => 0,
        };
    }

    pub inline fn Enter(self: *Context) noreturn {
        ContextEnter(@as(*allowzero void, @ptrFromInt(@intFromPtr(self))));
    }

    pub fn Dump(self: *Context) void {
        HAL.Console.Put(" rax 0x{x: <16}    rbx 0x{x: <16}    rcx 0x{x: <16}\n", .{ self.rax, self.rbx, self.rcx });
        HAL.Console.Put(" rdx 0x{x: <16}    rsi 0x{x: <16}    rdi 0x{x: <16}\n", .{ self.rdx, self.rsi, self.rdi });
        HAL.Console.Put(" rbp 0x{x: <16}     r8 0x{x: <16}     r9 0x{x: <16}\n", .{ self.rbp, self.r8, self.r9 });
        HAL.Console.Put(" r10 0x{x: <16}    r11 0x{x: <16}    r12 0x{x: <16}\n", .{ self.r10, self.r11, self.r12 });
        HAL.Console.Put(" r13 0x{x: <16}    r14 0x{x: <16}    r15 0x{x: <16}\n", .{ self.r13, self.r14, self.r15 });
        HAL.Console.Put(" rip 0x{x: <16}    rsp 0x{x: <16} rflags 0x{x: <16}\n", .{ self.rip, self.rsp, self.rflags });
        HAL.Console.Put(" error code: 0x{x}\n", .{self.errcode});
    }
};

pub const FloatContext = struct {
    data: [512]u8 align(16) = [_]u8{0} ** 512,

    pub fn Save(self: *FloatContext) void {
        asm volatile ("fxsave64 (%rax)"
            :
            : [state] "{rax}" (&self.data),
        );
    }
    pub fn Load(self: *FloatContext) void {
        asm volatile ("fxrstor64 (%rax)"
            :
            : [state] "{rax}" (&self.data),
        );
    }
};

const NativePTEEntry = packed struct {
    valid: u1 = 0,
    write: u1 = 0,
    user: u1 = 0,
    writeThrough: u1 = 0,
    cacheDisable: u1 = 0,
    reserved1: u2 = 0,
    pat: u1 = 0,
    reserved2: u4 = 0,
    phys: u51 = 0,
    noExecute: u1 = 0,
};

pub fn GetPTE(root: *void, index: usize) HAL.PTEEntry {
    const entries: []align(1) NativePTEEntry = @as([*]align(1) NativePTEEntry, @ptrCast(@alignCast(root)))[0..512];
    var entry: HAL.PTEEntry = HAL.PTEEntry{};
    entry.r = entries[index].valid;
    entry.w = entries[index].write;
    if (!noNX) {
        entry.x = ~entries[index].noExecute;
    } else {
        entry.x = 1;
    }
    entry.userSupervisor = ~entries[index].user;
    entry.nonCached = entries[index].cacheDisable;
    entry.writeThrough = entries[index].writeThrough;
    entry.writeCombine = entries[index].pat;
    entry.phys = @as(u52, @intCast(entries[index].phys));
    return entry;
}

pub fn SetPTE(root: *void, index: usize, entry: HAL.PTEEntry) void {
    var entries: []align(1) NativePTEEntry = @as([*]align(1) NativePTEEntry, @ptrCast(@alignCast(root)))[0..512];
    entries[index].valid = entry.r;
    entries[index].write = entry.w;
    if (!noNX) {
        entries[index].noExecute = ~entry.x;
    }
    entries[index].user = ~entry.userSupervisor;
    entries[index].cacheDisable = entry.nonCached | entry.writeCombine;
    entries[index].writeThrough = entry.writeThrough | entry.writeCombine;
    entries[index].pat = entry.writeCombine;
    entries[index].phys = @as(u51, @intCast(entry.phys & 0xfffffffff));
}

pub inline fn GetPTELevels() usize {
    return 4;
}

pub inline fn SwitchPT(root: *void) void {
    asm volatile ("mov %rax, %%cr3"
        :
        : [pt] "{rax}" (@intFromPtr(root)),
    );
}

pub inline fn InvalidatePage(page: usize) void {
    asm volatile ("invlpg (%rax)"
        :
        : [pg] "{rax}" (page),
    );
}

pub const ArchHCBData = struct {
    tss: gdt.TSS = gdt.TSS{},
    apicID: u32 = 0,
};

pub var irqISRs: [224]?*const fn (u16) callconv(.C) void = [_]?*const fn (u16) callconv(.C) void{null} ** 224;
pub const irqSearchStart = 16;

// x86_64 Exclusives
pub fn rdmsr(index: u32) u64 {
    var low: u32 = 0;
    var high: u32 = 0;
    asm volatile ("rdmsr"
        : [lo] "={rax}" (low),
          [hi] "={rdx}" (high),
        : [ind] "{rcx}" (index),
    );
    return (@as(u64, @intCast(high)) << 32) | @as(u64, @intCast(low));
}

pub fn wrmsr(index: u32, val: u64) void {
    const low: u32 = @as(u32, @intCast(val & 0xFFFFFFFF));
    const high: u32 = @as(u32, @intCast(val >> 32));
    asm volatile ("wrmsr"
        :
        : [lo] "{rax}" (low),
          [hi] "{rdx}" (high),
          [ind] "{rcx}" (index),
    );
}

// This CPUID struct and function orginates from the Rise operating system
// https://github.com/davidgm94/rise/blob/main/src/lib/arch/x86/common.zig
// Rise is licensed under the 3-clause BSD License
pub const CPUID = extern struct {
    eax: u32,
    ebx: u32,
    edx: u32,
    ecx: u32,
};

pub inline fn cpuid(leaf: u32) CPUID {
    var eax: u32 = undefined;
    var ebx: u32 = undefined;
    var edx: u32 = undefined;
    var ecx: u32 = undefined;

    asm volatile (
        \\cpuid
        : [eax] "={eax}" (eax),
          [ebx] "={ebx}" (ebx),
          [edx] "={edx}" (edx),
          [ecx] "={ecx}" (ecx),
        : [leaf] "{eax}" (leaf),
    );

    return CPUID{
        .eax = eax,
        .ebx = ebx,
        .edx = edx,
        .ecx = ecx,
    };
}

// Debugger
pub fn PrepareForDebug() void {
    while ((io.inb(0x64) & 1) != 0) { // Empty the PS/2 Keyboard Scancode Queue
        _ = io.inb(0x60);
    }
}

var isShiftPressed: bool = false;

pub fn DebugGet() u8 {
    while (true) {
        var status = io.inb(0x64);
        while ((status & 1) != 0) {
            const key = io.inb(0x60);
            if ((status & 0x20) != 0) {
                status = io.inb(0x64);
                continue;
            }
            if (key == 0x2a or key == 0x36) {
                isShiftPressed = true;
            } else if (key == 0xaa or key == 0xb6) {
                isShiftPressed = false;
            } else if (key < 128) {
                const char = if (isShiftPressed) HAL.Debug.PS2Keymap.shiftedMap[key] else HAL.Debug.PS2Keymap.unshiftedMap[key];
                if (char != 0) {
                    return char;
                }
            }
            status = io.inb(0x64);
        }
        std.atomic.spinLoopHint();
    }
}

pub fn GetStartupTimestamp() i64 {
    return initialUNIXTime;
}

pub fn GetCurrentTimestamp() [2]i64 { // Returns a Nanosecond Precision Timestamp (in reality the precision is actually ~100 ns precision due to limitations with the HPET)
    var ret: [2]i64 = .{ 0, 0 };
    const addr: usize = acpi.HPETAddr.?.address + 0xffff800000000000;
    const hpetAddr: [*]align(1) volatile u64 = @as([*]align(1) volatile u64, @ptrFromInt(addr));
    const us: u64 = (hpetAddr[30] / @as(u64, @intCast(apic.hpetTicksPer100NS)));
    ret[0] = initialUNIXTime + @as(i64, @intCast(us / 10000000));
    ret[1] = @rem(@as(i64, @intCast(us)), 10000000) * 100;
    return ret;
}
