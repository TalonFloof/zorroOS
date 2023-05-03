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

pub const HPETTable = extern struct {
    acpiHeader: Header align(1),
    hardwareRevId: u8 align(1),
    timerFlags: u8 align(1),
    pciVendorId: u16 align(1),
    addressSpaceId: u8 align(1),
    registerBitWidth: u8 align(1),
    registerBitOffset: u8 align(1),
    reserved2: u8 align(1),
    address: u64 align(1),
    hpetNumber: u8 align(1),
    minimumTick: u16 align(1),
    pageProtection: u8 align(1),
};

pub var MADTAddr: ?*Header = null;
pub var HPETAddr: ?*HPETTable = null;

pub fn initialize() void {
    if (rsdp_request.response) |rsdp_response| {
        if (@ptrToInt(rsdp_response.address) == 0) {
            @panic("System is not ACPI-compliant");
        }
        const rsdp: *RSDP = @ptrCast(*RSDP, rsdp_response.address);
        const rsdt = @intToPtr(*Header, @intCast(usize, rsdp.RSDT) + 0xffff800000000000);
        std.log.info("ACPI: RSDP 0x{x:0>16} (v{d:0>2} {s: <6})", .{ @ptrToInt(rsdp_response.address), rsdp.revision, rsdp.OEMID });
        const acpiEntries: []align(1) u32 = @intToPtr([*]align(1) u32, @ptrToInt(rsdt) + @sizeOf(Header))[0..((rsdt.length - @sizeOf(Header)) / 4)];
        std.log.info("ACPI: {s: <4} 0x{x:0>16} (v{d:0>2} {s: <6} {s: <8})", .{ @ptrCast([*]u8, &rsdt.signature)[0..4], @ptrToInt(rsdt), rsdt.revision, rsdt.OEM_ID, rsdt.OEM_table_ID });
        for (acpiEntries) |ptr| {
            const entry: *Header = @intToPtr(*Header, @intCast(usize, ptr) + 0xffff800000000000);
            std.log.info("ACPI: {s: <4} 0x{x:0>16} (v{d:0>2} {s: <6} {s: <8})", .{ @ptrCast([*]u8, &entry.signature)[0..4], @ptrToInt(entry), entry.revision, entry.OEM_ID, entry.OEM_table_ID });
            if (entry.signature == 0x43495041) {
                MADTAddr = entry;
            } else if (entry.signature == 0x54455048) {
                HPETAddr = @ptrCast(*HPETTable, entry);
            }
        }
    } else {
        @panic("System is not ACPI-compliant");
    }
    if (MADTAddr == null) {
        @panic("ACPI didn't provide an MADT and we don't know how to parse the MP table (if it even exist!)");
    }
    if (HPETAddr == null) {
        @panic("System appears to not have an HPET. An HPET is required to calibrate the Local APIC Timers");
    }
}
