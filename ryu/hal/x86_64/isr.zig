const HAL = @import("root").HAL;
const apic = @import("apic.zig");
const Memory = @import("root").Memory;

pub fn stub() void {} // To ensure that the compiler will not optimize this module out.

pub export fn ExceptionHandler(entry: u8, con: *HAL.Arch.Context, errcode: u32) callconv(.C) void {
    if (entry == 0x8) {
        HAL.Crash.Crash(.RyuDoubleFault, .{ con.rip, con.rsp, 0, 0 });
    } else if (entry == 0xe) {
        var addr = asm volatile ("mov %%cr2, %[ret]"
            : [ret] "={rax}" (-> usize),
        );
        const val1: usize = if (errcode & 2 == 0) Memory.Paging.AccessRead else Memory.Paging.AccessWrite;
        const val2: usize = if (errcode & 1 != 0) Memory.Paging.AccessIsValid else 0;
        const val3: usize = if (errcode & 4 == 0) Memory.Paging.AccessSupervisor else 0;
        const val4: usize = if (errcode & 16 != 0) Memory.Paging.AccessExecute else 0;
        Memory.Paging.PageFault(con.rip, addr, val1 | val2 | val3 | val4);
    } else if (entry == 0x2) {
        @panic("Non-maskable Interrupt!");
    }
}
pub export fn IRQHandler(entry: u8, con: *HAL.Arch.Context) callconv(.C) void {
    _ = entry;
    _ = con;
    apic.write(0xb0, 0);
}
