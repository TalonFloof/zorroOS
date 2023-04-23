const std = @import("std");
const limine = @import("limine");

export var rsdp_request: limine.RsdpRequest = .{};

const RSDP = extern struct {
    signature: [8]u8 align(1),
    checksum1: u8 align(1),
    OEMID: [6]u8 align(1),
    revision: u8 align(1),
    RSDT: u32 align(1),
    length: u32 align(1),
    XSDT: u64 align(1),
    checksum2: u8 align(1),
    reserved: [3]u8 align(1),

    comptime {
        if (@sizeOf(@This()) != 36) {
            @compileError("RSDP has improper sizing!");
        }
    }
};

pub const Header = extern struct {
    signature: u32 align(1),
    length: u32 align(1),
    revision: u8 align(1),
    checksum: u8 align(1),
    OEM_ID: [6]u8 align(1),
    OEM_table_ID: [8]u8 align(1),
    OEM_revision: u32 align(1),
    creator_ID: u32 align(1),
    creator_revision: u32 align(1),

    comptime {
        if (@sizeOf(@This()) != 0x24) {
            @compileError("ACPI Header has improper sizing!");
        }
    }
};

pub fn initialize() void {
    if (rsdp_request.response) |rsdp_response| {
        const rsdp: *RSDP = @ptrCast(*RSDP, rsdp_response.address);
        const xsdt = @intToPtr(*Header, switch (rsdp.revision == 2) {
            true => rsdp.XSDT,
            false => rsdp.RSDT,
        });
        _ = xsdt;
        std.log.info("ACPI: RSDP 0x{x:0>16} (v{d:0>2} {s: <6})", .{ @ptrToInt(rsdp_response.address), rsdp.revision, rsdp.OEMID });
    } else {
        @panic("System is not ACPI-compliant");
    }
}
