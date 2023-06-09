pub const isr = @import("isr.zig");
const HAL = @import("root").HAL;
const io = @import("io.zig");

const IDTEntry = packed struct { isrLow: u16, kernelCS: u16, ist: u8, attributes: u8, isrMid: u16, isrHigh: u32, zero: u32 };

const IDTPtr = packed struct {
    limit: u16,
    base: *const IDTEntry,
};

var IDT: [256]IDTEntry = undefined;
var IDTptr: IDTPtr = undefined;

extern const ISRTable: [256]*void;

pub fn initialize() void {
    IDTptr.limit = 0xffff;
    IDTptr.base = &IDT[0];

    for (0..256) |i|
        setDescriptor(i, ISRTable[i], if (i < 32) 0x8f else 0x8e);

    io.outb(0x21, 0xff);
    io.outb(0x29, 0xff);

    asm volatile (
        \\lidt (%[idt_ptr])
        :
        : [idt_ptr] "r" (&IDTptr),
    );
}

pub fn fastInit() void {
    asm volatile (
        \\lidt (%[idt_ptr])
        :
        : [idt_ptr] "r" (&IDTptr),
    );
}

pub fn setDescriptor(vector: usize, i: *void, flags: u8) void {
    const descriptor = &IDT[vector];
    descriptor.isrLow = @truncate(u16, @ptrToInt(i) & 0xFFFF);
    descriptor.kernelCS = 0x28;
    descriptor.attributes = flags;
    descriptor.isrMid = @truncate(u16, (@ptrToInt(i) >> 16) & 0xFFFFFFFF);
    descriptor.isrHigh = @truncate(u32, @ptrToInt(i) >> 32);
    descriptor.ist = 0;
    descriptor.zero = 0;
    isr.stub();
}
