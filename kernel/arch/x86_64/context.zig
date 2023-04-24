const std = @import("std");

const REG_IP = 256;
const REG_SP = 257;

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
    cs: u64 = 0x43,
    rflags: u64 = 0,
    rsp: u64 = 0,
    ss: u64 = 0x3b,

    // Arguments: RDI, RSI, RDX, RCX, R8, R9
    pub fn getReg(self: *Context, index: usize) usize {
        switch (index) {
            0 => {
                return self.rdi;
            },
            1 => {
                return self.rsi;
            },
            2 => {
                return self.rdx;
            },
            3 => {
                return self.rcx;
            },
            4 => {
                return self.r8;
            },
            5 => {
                return self.r9;
            },
            REG_IP => {
                return self.rip;
            },
            REG_SP => {
                return self.rsp;
            },
            else => {
                return 0;
            },
        }
    }
    pub fn setReg(self: *Context, index: usize, val: usize) void {
        switch (index) {
            0 => {
                self.rdi = val;
            },
            1 => {
                self.rsi = val;
            },
            2 => {
                self.rdx = val;
            },
            3 => {
                self.rcx = val;
            },
            4 => {
                self.r8 = val;
            },
            5 => {
                self.r9 = val;
            },
            REG_IP => {
                self.rip = val;
            },
            REG_SP => {
                self.rsp = val;
            },
            else => {},
        }
    }
    pub fn dump(self: *Context) void {
        std.log.debug("=== BEGIN CONTEXT DUMP ===\n", .{});
        std.log.debug("rax: 0x{x:0>16} rbx: 0x{x:0>16} rcx: 0x{x:0>16} rdx: 0x{x:0>16}\n", .{ self.rax, self.rbx, self.rcx, self.rdx });
        std.log.debug("rsi: 0x{x:0>16} rdi: 0x{x:0>16} rbp: 0x{x:0>16} rsp: 0x{x:0>16}\n", .{ self.rsi, self.rdi, self.rbp, self.rsp });
        std.log.debug(" r8: 0x{x:0>16}  r9: 0x{x:0>16} r10: 0x{x:0>16} r11: 0x{x:0>16}\n", .{ self.r8, self.r9, self.r10, self.r11 });
        std.log.debug("r12: 0x{x:0>16} r13: 0x{x:0>16} r14: 0x{x:0>16} r15: 0x{x:0>16}\n", .{ self.r12, self.r13, self.r14, self.r15 });
        std.log.debug("rip: 0x{x:0>16} rfl: 0x{x:0>16}  cs: 0x{x:0>4}\n", .{ self.rip, self.rflags, self.cs });
        std.log.debug("=== END CONTEXT DUMP ===\n", .{});
    }
};

pub const FloatContext = struct {
    data: [512]u8 = [_]u8{0} ** 512,

    pub fn save(self: *FloatContext) void {
        asm volatile ("fxsave64 (%rax)"
            :
            : [state] "{rax}" (@ptrToInt(&self.data)),
        );
    }
    pub fn load(self: *FloatContext) void {
        asm volatile ("fxrstor64 (%rax)"
            :
            : [state] "{rax}" (@ptrToInt(&self.data)),
        );
    }
};
