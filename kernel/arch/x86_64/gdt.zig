const std = @import("std");

var gdtEntries = [16]u64{
    0x0000000000000000, // 0x00: NULL
    0x00009a000000ffff, // 0x08: LIMINE 16-BIT KCODE
    0x000092000000ffff, // 0x10: LIMINE 16-BIT KDATA
    0x00cf9a000000ffff, // 0x18: LIMINE 32-BIT KCODE
    0x00cf92000000ffff, // 0x20: LIMINE 32-BIT KDATA
    0x00209A0000000000, // 0x28: 64-BIT KCODE
    0x0000920000000000, // 0x30: 64-BIT KDATA
    0x0000F20000000000, // 0x3B: 64-BIT UDATA
    0x0020FA0000000000, // 0x43: 64-BIT UCODE
    0,
    0,
    0,
    0,
    0,
    0,
    0,
};

const GDTRegister = packed struct {
    limit: u16,
    base: *const u64,
};

const TSS = packed struct {};

pub fn initialize() void {
    var gdtr = GDTRegister{
        .limit = (16 * 8) - 1,
        .base = @ptrCast(*const u64, &gdtEntries),
    };
    asm volatile (
        \\lgdt (%rdi)
        \\mov $0x30, %ax
        \\mov %ax, %ds
        \\mov %ax, %es
        \\mov %ax, %ss
        \\mov $0x3b, %ax
        \\mov %ax, %fs
        \\mov %ax, %gs
        :
        : [ptr] "{rdi}" (&gdtr),
        : "rax"
    );
}
