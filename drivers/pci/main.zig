const devlib = @import("devlib");
const std = @import("std");
const pci = @import("pci.zig");

const PCI_VENDOR_ID: u16 = 0x00;
const PCI_DEVICE_ID: u16 = 0x02;
const PCI_COMMAND: u16 = 0x04;
const PCI_STATUS: u16 = 0x06;
const PCI_REVISION_ID: u16 = 0x08;
const PCI_SUBSYSTEM_ID: u16 = 0x2e;
const PCI_PROG_IF: u16 = 0x09;
const PCI_SUBCLASS: u16 = 0x0a;
const PCI_CLASS: u16 = 0x0b;
const PCI_CACHE_LINE_SIZE: u16 = 0x0c;
const PCI_LATENCY_TIMER: u16 = 0x0d;
const PCI_HEADER_TYPE: u16 = 0x0e;
const PCI_BIST: u16 = 0x0f;
const PCI_BAR0: u16 = 0x10;
const PCI_BAR1: u16 = 0x14;
const PCI_BAR2: u16 = 0x18;
const PCI_BAR3: u16 = 0x1c;
const PCI_BAR4: u16 = 0x20;
const PCI_BAR5: u16 = 0x24;
const PCI_INTERRUPT_LINE: u16 = 0x3c;
const PCI_INTERRUPT_PIN: u16 = 0x3d;
const PCI_SECONDARY_BUS: u16 = 0x19;

pub export var DriverInfo = devlib.RyuDriverInfo{
    .apiMinor = 1,
    .apiMajor = 0,
    .drvName = "PCIDriver",
    .exportedDispatch = @alignCast(@constCast(@ptrCast(&interface))),
    .loadFn = &LoadDriver,
    .unloadFn = &UnloadDriver,
};

fn ryuWriteString(_: @TypeOf(.{}), string: []const u8) error{}!usize {
    DriverInfo.krnlDispatch.?.putRaw(@constCast(@ptrCast(string.ptr)), string.len);
    return string.len;
}

pub const Writer = std.io.Writer(@TypeOf(.{}), error{}, ryuWriteString);
pub const writer = Writer{ .context = .{} };

pub fn ReadU8(bus: u8, slot: u8, fun: u8, offset: u16) callconv(.C) u8 {
    devlib.io.outw(0xcf8, (@as(u32, @intCast(bus)) << 16) | (@as(u32, @intCast(slot)) << 11) | (@as(u32, @intCast(fun)) << 8) | (@as(u32, @intCast(offset)) & 0xFC) | 0x80000000);
    return @truncate(devlib.io.inw(0xcfc) >> @intCast((offset & 3) * 8));
}

pub fn ReadU16(bus: u8, slot: u8, fun: u8, offset: u16) callconv(.C) u16 {
    devlib.io.outw(0xcf8, (@as(u32, @intCast(bus)) << 16) | (@as(u32, @intCast(slot)) << 11) | (@as(u32, @intCast(fun)) << 8) | (@as(u32, @intCast(offset)) & 0xFC) | 0x80000000);
    return @truncate(devlib.io.inw(0xcfc) >> @intCast((offset & 2) * 8));
}

pub fn ReadU32(bus: u8, slot: u8, fun: u8, offset: u16) callconv(.C) u32 {
    devlib.io.outw(0xcf8, (@as(u32, @intCast(bus)) << 16) | (@as(u32, @intCast(slot)) << 11) | (@as(u32, @intCast(fun)) << 8) | (@as(u32, @intCast(offset)) & 0xFC) | 0x80000000);
    return devlib.io.inw(0xcfc);
}

pub fn WriteU8(bus: u8, slot: u8, fun: u8, offset: u16, data: u8) callconv(.C) void {
    const oldData: u32 = ReadU32(bus, slot, fun, offset);
    const pos: u5 = @intCast((offset & 0x3) * 8);
    devlib.io.outw(0xcf8, (@as(u32, @intCast(bus)) << 16) | (@as(u32, @intCast(slot)) << 11) | (@as(u32, @intCast(fun)) << 8) | (@as(u32, @intCast(offset)) & 0xFC) | 0x80000000);
    devlib.io.outw(0xcfc, (oldData & (~(@as(u32, @intCast(0xFF)) << pos))) | (@as(u32, @intCast(data)) << pos));
}

pub fn WriteU16(bus: u8, slot: u8, fun: u8, offset: u16, data: u16) callconv(.C) void {
    const oldData: u32 = ReadU32(bus, slot, fun, offset);
    const pos: u5 = @intCast((offset & 0x2) * 8);
    devlib.io.outw(0xcf8, (@as(u32, @intCast(bus)) << 16) | (@as(u32, @intCast(slot)) << 11) | (@as(u32, @intCast(fun)) << 8) | (@as(u32, @intCast(offset)) & 0xFC) | 0x80000000);
    devlib.io.outw(0xcfc, (oldData & (~(@as(u32, @intCast(0xFFFF)) << pos))) | (@as(u32, @intCast(data)) << pos));
}

pub fn WriteU32(bus: u8, slot: u8, fun: u8, offset: u16, data: u32) callconv(.C) void {
    devlib.io.outw(0xcf8, (@as(u32, @intCast(bus)) << 16) | (@as(u32, @intCast(slot)) << 11) | (@as(u32, @intCast(fun)) << 8) | (@as(u32, @intCast(offset)) & 0xFC) | 0x80000000);
    devlib.io.outw(0xcfc, data);
}

pub fn ReadBAR(bus: u8, slot: u8, fun: u8, bar: u8) callconv(.C) u64 {
    const addr = (@as(u16, @intCast(bar)) * 4) + PCI_BAR0;
    const low = @as(u64, @intCast(ReadU32(bus, slot, fun, addr)));
    const Type = low & 7;
    if (Type == 0) {
        return low & (~@as(u64, @intCast(0xf)));
    } else if (low & 1 == 1) {
        return low & (~@as(u64, @intCast(0x3)));
    }
    const high = @as(u64, @intCast(ReadU32(bus, slot, fun, addr + 4)));
    return (low & (~@as(u64, @intCast(0xf)))) | (high << 32);
}

pub fn SearchCapability(bus: u8, slot: u8, func: u8, cap: u8) callconv(.C) u16 {
    if (ReadU8(bus, slot, func, PCI_STATUS) & 0x10 == 0x10) {
        var capOff = @as(u16, @intCast(ReadU8(bus, slot, func, 0x34)));
        while (capOff != 0) {
            if (ReadU8(bus, slot, func, capOff) == cap) {
                return capOff;
            }
            capOff = @as(u16, @intCast(ReadU8(bus, slot, func, capOff + 1)));
        }
        return 0;
    }
    return 0;
}

pub fn AcquireIRQ(bus: u8, slot: u8, func: u8, f: *const fn (u16) callconv(.C) void) callconv(.C) u16 {
    var msix = SearchCapability(bus, slot, func, 0x11);
    var msi = SearchCapability(bus, slot, func, 0x5);
    if (msi != 0) {
        const msgCtl = ((ReadU16(bus, slot, func, msi + 2) & (~@as(u16, 0x70))) & (~@as(u16, 0x100))) | 0x1;
        const irq = DriverInfo.krnlDispatch.?.attachDetatchIRQ(65535, f) + 0x20;
        if ((msgCtl & 0x80) == 0x80) {
            WriteU32(bus, slot, func, msi + 0x4, 0xfee00000);
            WriteU32(bus, slot, func, msi + 0x8, 0);
            WriteU16(bus, slot, func, msi + 0xc, irq);
        } else {
            WriteU32(bus, slot, func, msi + 0x4, 0xfee00000);
            WriteU16(bus, slot, func, msi + 0x8, irq);
        }
        WriteU16(bus, slot, func, msi + 2, msgCtl);
        WriteU16(bus, slot, func, PCI_COMMAND, ReadU16(bus, slot, func, PCI_COMMAND) | 1024);
        return irq - 0x20;
    } else if (msix != 0) {
        const msgCtl = ReadU16(bus, slot, func, msix + 2) | 0x8000;
        const irq = DriverInfo.krnlDispatch.?.attachDetatchIRQ(65535, f) + 0x20;
        const tabPos: u16 = @truncate(ReadU32(bus, slot, func, msix + 4));
        const addr: u64 = ReadBAR(bus, slot, func, @truncate(tabPos & 7)) + (tabPos & (~@as(u64, @intCast(7))));
        const p = @as([*]volatile u64, @ptrFromInt(@as(usize, @intCast(addr)) + 0xffff800000000000));
        p[1] = @intCast(irq);
        p[0] = 0xfee00000;
        WriteU16(bus, slot, func, msix + 2, msgCtl);
        WriteU16(bus, slot, func, PCI_COMMAND, ReadU16(bus, slot, func, PCI_COMMAND) | 1024);
        return irq - 0x20;
    }
    return 0;
}

pub fn PCIDevToString(class: u8, subClass: u8, progIF: u8) []const u8 {
    return switch (class) {
        0x1 => switch (subClass) {
            0 => "Parallel SCSI Bus Controller",
            1 => switch (progIF) {
                0x0 => "IDE Controller (ISA Compatability Only)",
                0x5 => "IDE Controller (PCI Native Only)",
                0xa => "IDE Controller (ISA Compatible Controller)",
                0xf => "IDE Controller (PCI Native)",
                0x80 => "IDE Controller (ISA Compatability Only, Supports Bus Mastering)",
                0x85 => "IDE Controller (PCI Native Only, Supports Bus Mastering)",
                0x8a => "IDE Controller (ISA Compatible Controller Supports Bus Mastering)",
                0x8f => "IDE Controller (PCI Native Supports Bus Mastering)",
                else => "IDE Controller",
            },
            2 => "Floppy Diskette Controller",
            3 => "IPI-Bus Controller",
            4 => "Hardware RAID Controller",
            5 => "ATA Controller",
            6 => switch (progIF) {
                0 => "Specialized AHCI Controller",
                1 => "SATA AHCI Controller",
                2 => "Serial SATA Controller",
                else => "Unidentifiable SATA Controller",
            },
            7 => "Serial-Attached SCSI (SAS) Controller",
            8 => switch (progIF) {
                1 => "NVMHCI",
                2 => "NVMe Drive",
                else => "Unidentifiable NVM Device",
            },
            else => "Unidentifiable Mass Storage Device",
        },
        0x2 => switch (subClass) {
            0 => "Ethernet Controller",
            1 => "Token Ring Controller",
            2 => "FDDI Controller",
            3 => "ATM Controller",
            4 => "ISDN Controller",
            5 => "WorldFip Controller",
            6 => "PICMG Controller",
            7 => "InfiniBand Controller",
            8 => "Fabric Controller",
            else => "Unidentifiable Network Controller",
        },
        0x3 => switch (subClass) {
            0 => "VGA-Compatable Graphics Controller",
            1 => "XGA Graphics Controller",
            2 => "Non-VGA Compatible Graphics Controller",
            else => "Unidentifiable Graphics Controller",
        },
        0x4 => switch (subClass) {
            0 => "Multimedia Video Controller",
            1 => "Multimedia Audio Controller",
            2 => "Computer Telephony Device",
            3 => "Audio Device",
            else => "Unidentifiable Multimedia Controller",
        },
        0x5 => switch (subClass) {
            0x0 => "RAM Controller",
            0x1 => "Flash Controller",
            else => "Unidentifiable Memory Controller",
        },
        0x6 => switch (subClass) {
            0x0 => "Host Bridge",
            0x1 => "ISA Bridge",
            0x2 => "EISA Bridge",
            0x3 => "MCA Bridge",
            0x4 => switch (progIF) {
                0x0 => "PCI-to-PCI Bridge (Normal Decode)",
                0x1 => "PCI-to-PCI Bridge (Subtractive Decode)",
                else => "PCI-to-PCI Bridge",
            },
            0x5 => "PCMCIA Bridge",
            0x6 => "NuBus Bridge",
            0x7 => "CardBus Bridge",
            0x8 => switch (progIF) {
                0x0 => "RACEway Bridge (Transparent Mode)",
                0x1 => "RACEway Bridge (Endpoint Mode)",
                else => "RACEway Bridge",
            },
            0x9 => switch (progIF) {
                0x40 => "PCI-to-PCI Bridge (Semi-Transparent, Primary Bus toward Host CPU)",
                0x80 => "PCI-to-PCI Bridge (Semi-Transparent, Secondary Bus toward Host CPU)",
                else => "PCI-to-PCI Bridge",
            },
            0xa => "InfiniBand-to-PCI Host Bridge",
            else => "Unidentifiable Bridge",
        },
        0x7 => switch (subClass) {
            0x0 => switch (progIF) {
                0x0 => "8250-Compatible (XT) Serial Controller",
                0x1 => "16450-Compatible Serial Controller",
                0x2 => "16550-Compatible Serial Controller",
                0x3 => "16650-Compatible Serial Controller",
                0x4 => "16750-Compatible Serial Controller",
                0x5 => "16850-Compatible Serial Controller",
                0x6 => "16950-Compatible Serial Controller",
                else => "Serial Controller",
            },
            0x1 => switch (progIF) {
                0x0 => "Standard Parallel Port",
                0x1 => "Bi-Directional Parallel Port",
                0x2 => "ECP 1.X Compliant Parallel Port",
                0x3 => "IEEE 1284 Controller",
                0xfe => "IEEE 1284 Target Device",
                else => "Unidentifiable Parallel Controller",
            },
            0x2 => "Multiport Serial Controller",
            0x3 => switch (progIF) {
                0x0 => "Generic Modem",
                0x1 => "Hayes 16450-Compatible Modem",
                0x2 => "Hayes 16550-Compatible Modem",
                0x3 => "Hayes 16650-Compatible Modem",
                0x4 => "Hayes 16750-Compatible Modem",
                else => "Unidentifiable Modem",
            },
            0x4 => "IEEE 488.1/2 (GPIB) Controller",
            0x5 => "Smart Card Controller",
            else => "Unidentifiable Simple Communication Controller",
        },
        0x8 => switch (subClass) {
            0x0 => switch (progIF) {
                0x0 => "8259-Compatible PIC",
                0x1 => "ISA-Compatible PIC",
                0x2 => "EISA-Compatible PIC",
                0x10 => "I/O APIC",
                0x20 => "I/O(x) APIC",
                else => "Unidentifiable PIC",
            },
            0x1 => switch (progIF) {
                0x0 => "8237-Compatible DMA Controller",
                0x1 => "ISA-Compatible DMA Controller",
                0x2 => "EISA-Compatible DMA Controller",
                else => "Unidentifiable DMA Controller",
            },
            0x2 => switch (progIF) {
                0x0 => "8254-Compatible Timer (PIT)",
                0x1 => "ISA-Compatible Timer",
                0x2 => "EISA-Compatible Timer",
                0x3 => "High Precision Event Timer (HPET)",
                else => "Unidentifiable Timer",
            },
            0x3 => switch (progIF) {
                0x0 => "Generic Real-Time Clock",
                0x1 => "ISA-Compatible Real-Time Clock",
                else => "Unidentifiable Real-Time Clock",
            },
            0x4 => "PCI Hotplug Controller",
            0x5 => "SD Host Controller",
            0x6 => "IOMMU",
            else => "Unidentifiable Base System Peripheral",
        },
        0x9 => switch (subClass) {
            0x0 => "Keyboard Controller",
            0x1 => "Digitizer Pen",
            0x2 => "Mouse Controller",
            0x3 => "Scanner Controller",
            0x4 => switch (progIF) {
                0 => "Generic Gameport Controller",
                0x10 => "Extended Gameport Controller",
                else => "Gameport Controller",
            },
            else => "Unidentifiable HID Controller",
        },
        0xc => switch (subClass) {
            0x0 => switch (progIF) {
                0x0 => "Generic FireWire (IEEE 1394) Controller",
                0x10 => "OHCI FireWire (IEEE 1394) Controller",
                else => "FireWire (IEEE 1394) Controller",
            },
            0x1 => "ACCESS Bus Controller",
            0x2 => "SSA",
            0x3 => switch (progIF) {
                0x0 => "UHCI (USB 1.0) Controller",
                0x10 => "OHCI (USB 1.1) Controller",
                0x20 => "EHCI (USB 2.0) Controller",
                0x30 => "XHCI (USB 3.0) Controller",
                0xfe => "USB Device",
                else => "Unidentifiable USB Controller",
            },
            0x4 => "Fibre Channel",
            0x5 => "SMBus Controller",
            0x6 => "InfiniBand Controller",
            0x7 => switch (progIF) {
                0 => "SMIC IPMI Interface",
                1 => "Keyboard Controller Style IPMI Interface",
                2 => "Block Transfer Style IPMI Interface",
                else => "IPMI Interface",
            },
            0x8 => "SERCOS Interface (IEC 61491)",
            0x9 => "CANbus Controller",
            else => "Unidentifiable Serial Bus Controller",
        },
        0xd => switch (subClass) {
            0x0 => "iRDA Compatible Controller",
            0x1 => "Consumer IR Controller",
            0x10 => "RF Controller",
            0x11 => "Bluetooth Controller",
            0x12 => "Broadband Controller",
            0x20 => "Ethernet Controller (802.1a)",
            0x21 => "Ethernet Controller (802.1b)",
            else => "Unidentifiable Wireless Controller",
        },
        0xe => switch (subClass) {
            0x0 => "I2O",
            else => "Unidentifiable Intelligent Controller",
        },
        0xf => switch (subClass) {
            0x1 => "Satellite TV Controller",
            0x2 => "Satellite Audio Controller",
            0x3 => "Satellite Voice Controller",
            0x4 => "Satellite Data Controller",
            else => "Unidentifiable Satellite Controller",
        },
        0x10 => switch (subClass) {
            0x0 => "Networking and Computing-based Encryption Controller",
            0x10 => "Multimedia-based Encryption Controller",
            else => "Unidentifiable Encryption Controller",
        },
        0x11 => switch (subClass) {
            0x0 => "DPIO Modules",
            0x1 => "Performance Counters",
            0x10 => "Communication Synchronizer",
            0x20 => "Signal Processing Management",
            else => "Unidentifiable Signal Processing Controller",
        },
        0x12 => "Processing Accelerator",
        0x13 => "Non-Essential Instrumentation",
        else => "Unidentifiable PCI Device",
    };
}

pub fn GetDevices() callconv(.C) *pci.PCIDevice {
    if (pciHead == null) {
        DriverInfo.krnlDispatch.?.put("Scanning PCI Buses...\n");
        var bus: u16 = 0;
        while (bus < 256) : (bus += 1) {
            var slot: u8 = 0;
            while (slot < 32) : (slot += 1) {
                var func: u8 = 0;
                while (func < 8) : (func += 1) {
                    if (ReadU16(@intCast(bus), slot, func, PCI_VENDOR_ID) != 0xFFFF) {
                        const vendor = ReadU16(@intCast(bus), slot, func, PCI_VENDOR_ID);
                        const device = ReadU16(@intCast(bus), slot, func, PCI_DEVICE_ID);
                        const class = ReadU8(@intCast(bus), slot, func, PCI_CLASS);
                        const subclass = ReadU8(@intCast(bus), slot, func, PCI_SUBCLASS);
                        const progif = ReadU8(@intCast(bus), slot, func, PCI_PROG_IF);
                        DriverInfo.krnlDispatch.?.putNumber(@intCast(bus), 16, false, '0', 2);
                        DriverInfo.krnlDispatch.?.put(":");
                        DriverInfo.krnlDispatch.?.putNumber(@intCast(slot), 16, false, '0', 2);
                        DriverInfo.krnlDispatch.?.put(".");
                        DriverInfo.krnlDispatch.?.putNumber(@intCast(func), 16, false, ' ', 0);
                        DriverInfo.krnlDispatch.?.put(": ");
                        DriverInfo.krnlDispatch.?.put(@ptrCast(PCIDevToString(class, subclass, progif).ptr));
                        DriverInfo.krnlDispatch.?.put("\n         Vendor/Device: 0x");
                        DriverInfo.krnlDispatch.?.putNumber(@intCast(vendor), 16, false, '0', 4);
                        DriverInfo.krnlDispatch.?.put(":0x");
                        DriverInfo.krnlDispatch.?.putNumber(@intCast(device), 16, false, '0', 4);
                        DriverInfo.krnlDispatch.?.put("\n");
                        var entry: *pci.PCIDevice = @as(*pci.PCIDevice, @alignCast(@ptrCast(DriverInfo.krnlDispatch.?.staticAlloc(@sizeOf(pci.PCIDevice)))));
                        entry.bus = @truncate(bus);
                        entry.slot = slot;
                        entry.func = func;
                        entry.vendor = vendor;
                        entry.device = device;
                        entry.class = class;
                        entry.subclass = subclass;
                        entry.progif = progif;
                        entry.next = pciHead;
                        pciHead = entry;
                    }
                }
            }
        }
        // TODO: Add PCIe Enumeration
    }
    return pciHead.?;
}

const interface: pci.PCIInterface = pci.PCIInterface{
    .readU8 = &ReadU8,
    .readU16 = &ReadU16,
    .readU32 = &ReadU32,
    .writeU8 = &WriteU8,
    .writeU16 = &WriteU16,
    .writeU32 = &WriteU32,
    .readBar = &ReadBAR,
    .searchCapability = &SearchCapability,
    .acquireIRQ = &AcquireIRQ,
    .getDevices = &GetDevices,
};

var pciHead: ?*pci.PCIDevice = null;

pub fn LoadDriver() callconv(.C) devlib.Status {
    if (DriverInfo.krnlDispatch) |dispatch| {
        _ = dispatch;
        _ = GetDevices(); // Just in case...
        return .Okay;
    }
    return .Failure;
}

pub fn UnloadDriver() callconv(.C) devlib.Status {
    return .Okay;
}

pub fn panic(msg: []const u8, stacktrace: ?*std.builtin.StackTrace, wat: ?usize) noreturn {
    _ = wat;
    _ = stacktrace;
    while (true) {
        DriverInfo.krnlDispatch.?.abort(@ptrCast(msg.ptr));
    }
}
