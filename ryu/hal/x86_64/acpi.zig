const std = @import("std");
const HAL = @import("root").HAL;
const limine = @import("limine");
const apic = @import("apic.zig");

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

pub const MADTTable = extern struct {
    acpiHeader: Header align(1),
    lapicAddr: u32 align(1),
    flags: u32 align(1),
    firstEntry: MADTRecordHeader align(1),
};

pub const MADTRecordHeader = extern struct {
    recordType: u8 align(1),
    recordLength: u8 align(1),
    recordData: u8 align(1), // Is used to get the pointer of the data, this shouldn't be used for any other purpose.
};

pub const MADTIOApicRecord = extern struct {
    id: u8 align(1),
    reserved: u8 align(1),
    addr: u32 align(1),
    gsiBase: u32 align(1),
};

pub const MADTIRQRedirectRecord = extern struct {
    busSource: u8 align(1),
    irqSource: u8 align(1),
    gsi: u32 align(1),
    flags: u16 align(1),
};

pub var MADTAddr: ?*MADTTable = null;
pub var HPETAddr: ?*HPETTable = null;

pub fn initialize() void {
    if (rsdp_request.response) |rsdp_response| {
        if (@ptrToInt(rsdp_response.address) == 0) {
            HAL.Crash.Crash(.RyuNoACPI, .{ 0, 0, 0, 0 });
        }
        const rsdp: *RSDP = @ptrCast(*RSDP, rsdp_response.address);
        const rsdt = @intToPtr(*Header, @intCast(usize, rsdp.RSDT) + 0xffff800000000000);
        HAL.Console.Put("ACPI: RSDP 0x{x:0>16} (v{d:0>2} {s: <6})\n", .{ @ptrToInt(rsdp_response.address), rsdp.revision, rsdp.OEMID });
        const acpiEntries: []align(1) u32 = @intToPtr([*]align(1) u32, @ptrToInt(rsdt) + @sizeOf(Header))[0..((rsdt.length - @sizeOf(Header)) / 4)];
        HAL.Console.Put("ACPI: {s: <4} 0x{x:0>16} (v{d:0>2} {s: <6} {s: <8})\n", .{ @ptrCast([*]u8, &rsdt.signature)[0..4], @ptrToInt(rsdt), rsdt.revision, rsdt.OEM_ID, rsdt.OEM_table_ID });
        for (acpiEntries) |ptr| {
            const entry: *Header = @intToPtr(*Header, @intCast(usize, ptr) + 0xffff800000000000);
            HAL.Console.Put("ACPI: {s: <4} 0x{x:0>16} (v{d:0>2} {s: <6} {s: <8})\n", .{ @ptrCast([*]u8, &entry.signature)[0..4], @ptrToInt(entry), entry.revision, entry.OEM_ID, entry.OEM_table_ID });
            if (entry.signature == 0x43495041) {
                MADTAddr = @ptrCast(*MADTTable, entry);
            } else if (entry.signature == 0x54455048) {
                HPETAddr = @ptrCast(*HPETTable, entry);
            }
        }
    } else {
        HAL.Crash.Crash(.RyuNoACPI, .{ 0, 0, 0, 0 });
    }
    if (MADTAddr) |madt| {
        var entry = &madt.firstEntry;
        while (@ptrToInt(entry) < @ptrToInt(madt) + madt.acpiHeader.length) : (entry = @intToPtr(*MADTRecordHeader, @ptrToInt(entry) + entry.recordLength)) {
            if (entry.recordType == 1) { // I/O APIC Record
                var data = @ptrCast(*MADTIOApicRecord, &entry.recordData);
                if (data.gsiBase == 0) {
                    apic.ioapic_regSelect = @intToPtr(*allowzero u32, @intCast(usize, data.addr));
                    apic.ioapic_ioWindow = @intToPtr(*allowzero u32, @intCast(usize, data.addr) + 0x10);
                }
            } else if (entry.recordType == 2) { // I/O APIC IRQ Redirect
                var data = @ptrCast(*MADTIRQRedirectRecord, &entry.recordData);
                apic.ioapic_redirect[data.gsi] = @intCast(u8, data.irqSource);
                if (data.irqSource != data.gsi) {
                    apic.ioapic_redirect[data.irqSource] = 0xff;
                }
                if ((data.flags & 2) != 0) {
                    apic.ioapic_activelow[data.gsi] = true;
                }
                if ((data.flags & 4) != 0) {
                    apic.ioapic_leveltrig[data.gsi] = true;
                }
            }
        }
        if (@ptrToInt(apic.ioapic_regSelect) == 0) {
            @panic("No I/O APIC was specified in the MADT!");
        }
    } else {
        @panic("ACPI didn't provide an MADT and we don't know how to parse the MP table (if it even exist!)");
    }
    if (HPETAddr == null) {
        @panic("System appears to not have an HPET. An HPET is required to calibrate the Local APIC Timers");
    }
}
