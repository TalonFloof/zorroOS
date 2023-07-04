const std = @import("std");
const Drivers = @import("root").Drivers;
const Memory = @import("root").Memory;
const devlib = @import("devlib");
const HAL = @import("hal");

const ELFObjType = enum(u16) {
    Relocatable = 1,
    Executable = 2,
    Shared = 3,
    Core = 4,
};

const ELFArch = enum(u16) {
    NoSpecific = 0x00,
    AttWE32100 = 0x01, // why this processor first?
    Sparc = 0x02,
    Intelx86 = 0x03, // kinda mid tbh
    Motorola68000 = 0x04, // better than i386 ngl
    Motorola88000 = 0x05, // what is this exactly?
    IntelMCU = 0x06, // huh
    Intel80860 = 0x07,
    Mips = 0x08, // hands down, best processor ever made
    IBMSystem370 = 0x09, // you guys still use these? lmao
    MipsRS3000LE = 0x0a,
    HpPARISC = 0x0e,
    Intel80960 = 0x13,
    PowerPC32 = 0x14, // baCkWaRd PagE tAbLE maKe mE waNnA kMs
    PowerPC64 = 0x15, // not like you're any better
    S390x = 0x16,
    IbmSpuSpc = 0x17,
    NecV800 = 0x24,
    FujisuFR20 = 0x25,
    TrwRH32 = 0x26,
    MotorolaRCE = 0x27,
    ARM32 = 0x28,
    DigitalAlpha = 0x29, // a revolutionary product for its time, too bad it was already too late for Digital
    SuperH = 0x2a,
    SparcV9 = 0x2b,
    SiemensTriCore = 0x2c,
    ArgonautRISC = 0x2d, // wow how creative, your processor is called RISC omg
    HitachiH8_300 = 0x2e,
    HitachiH8_300H = 0x2f,
    HitachiH8S = 0x30,
    HitachiH8_500 = 0x31,
    IntelItanium = 0x32, // maybe we should forget about this one...
    StanfordMIPSX = 0x33,
    MotorolaColdFire = 0x34, // how does one make fire cold?
    MotorolaM68HC12 = 0x35,
    FujitsuMMAMediaAccel = 0x36,
    SiemensPCP = 0x37,
    SonyNCPU = 0x38,
    DensoNDR1 = 0x39,
    MotorolaStarCore = 0x3a, // is this like the opposite of coldfire?
    ToyotaME16 = 0x3b, // okay what's up with these weird architectures...
    STMicroelecST100 = 0x3c,
    ALCTinyJ = 0x3d,
    AMD64 = 0x3e, // YES ITS AMD64 NOT x86_64 OR FRICKING inTeL 64
    SonyDSP = 0x3f,
    DigitalPDP10 = 0x40, // who still uses a pdp-10?
    DigitalPDP11 = 0x41,
    SiemensFX66 = 0x42,
    STMicroElecST9 = 0x43,
    STMicroElecST7 = 0x44,
    MotorolaMC68HC16 = 0x45,
    MotorolaMC68HC11 = 0x46,
    MotorolaMC68HC08 = 0x47,
    MotorolaMC68HC05 = 0x48,
    SiliconGraphicsSVx = 0x49,
    STMicroElecST19 = 0x4a,
    DigitalVAX = 0x4b, // the machine which has an instruction for calculating the quadradic formula for some reason
    AxisCom32 = 0x4c,
    InfineonTech32 = 0x4d,
    Element14DSP = 0x4e,
    LSILogic = 0x4f,
    TMS320C6000 = 0x8c,
    MCSTElbrusE2k = 0xaf,
    ARM64 = 0xb7,
    ZilogZ80 = 0xdc, // Our lord and savior, the Zilog Z80 :3
    RISCV = 0xf3, // an actual RISC processor
    BerkeleyPacketFilter = 0xf7, // bro what
    WDC65C816 = 0x101, // 16-bit 6502 be like
};

const ELFHeader = packed struct {
    magic: u32 = 0x464C457F, // "\x7fELF"
    bits: u8,
    endian: u8,
    headerVer: u8,
    abi: u8,
    unused: u64 = 0,
    objType: ELFObjType,
    arch: ELFArch,
    version: u32,
    programEntryPos: u64,
    phtPos: u64, // Program Header Table Position
    shtPos: u64, // Section Header Table Position
    flags: u32,
    headerSize: u16,
    phtEntrySize: u16,
    phtEntryCount: u16,
    shtEntrySize: u16,
    shtEntryCount: u16,
    shtNameIndex: u16,

    comptime {
        if (@sizeOf(@This()) != 64) {
            @compileError("Size of ELFHeader is not 64 bytes!");
        }
    }
};

const ELFProgramHeader = extern struct {
    type: u32 align(1),
    flags: u32 align(1),
    offset: u64 align(1),
    vaddr: u64 align(1),
    paddr: u64 align(1),
    fileSize: u64 align(1),
    memSize: u64 align(1),
    alignment: u64 align(1),
};

const ELFSectionHeader = extern struct {
    name: u32 align(1),
    type: u32 align(1),
    flags: u64 align(1),
    addr: u64 align(1),
    offset: u64 align(1),
    size: u64 align(1),
    link: u32 align(1),
    info: u32 align(1),
    addralign: u64 align(1),
    entsize: u64 align(1),
};

const ELFSymbol = extern struct {
    name: u32 align(1),
    info: u8 align(1),
    other: u8 align(1),
    shndx: u16 align(1),
    value: u64 align(1),
    size: u64 align(1),

    comptime {
        if (@alignOf(@This()) != 1) {
            @compileError("Wrong Alignment for ELFSymbol!");
        }
    }
};

const ELFRela = extern struct {
    offset: u64 align(1),
    info: u64 align(1),
    addend: i64 align(1),
};

const ELFRelocType = enum(u32) {
    X86_64_64 = 1,
    X86_64_32 = 10,
    X86_64_32S = 11,
    X86_64_PC32 = 2,
    X86_64_PLT32 = 4,
    X86_64_RELATIVE = 8,
};

const ELFLoadError = error{
    BadMagic,
    Not64Bit,
    IncorrectArcitecture,
    NotRelocatable,
    NotDynamic,
    NotExecutable,
    UnrecognizedRelocation,
    NotImplemented,
    NoDriverInfo,
};

const ELFLoadType = enum {
    Normal,
    Driver,
};

pub fn LoadELF(ptr: *void, loadType: ELFLoadType, pd: ?Memory.Paging.PageDirectory) ELFLoadError!?usize {
    var header: *ELFHeader = @as(*ELFHeader, @ptrCast(@alignCast(ptr)));
    if (header.magic != 0x464C457F) {
        return ELFLoadError.BadMagic;
    }
    if (header.bits != 2) {
        return ELFLoadError.Not64Bit;
    }
    if (header.objType != .Relocatable and loadType == .Driver) {
        return ELFLoadError.NotRelocatable;
    } else if (header.objType != .Executable and loadType == .Normal) {
        return ELFLoadError.NotExecutable;
    }
    if (loadType == .Normal) {
        var i: usize = 0;
        while (i < header.phtEntryCount) : (i += 1) {
            var entry: *ELFProgramHeader = @as(*ELFProgramHeader, @ptrFromInt(@intFromPtr(ptr) + header.phtPos + (i * @as(usize, @intCast(header.phtEntrySize)))));
            if (entry.type == 1) {
                const trueSize: usize = @as(usize, @intCast(if (entry.memSize % 4096 > 0) (entry.memSize & (~@as(u64, @intCast(0xFFF)))) + 4096 else entry.memSize));
                var addr = @as(usize, @intCast(entry.vaddr));
                var off: usize = 0;
                while (addr < @as(usize, @intCast(entry.vaddr)) + trueSize) : (addr += 4096) {
                    var page = Memory.PFN.AllocatePage(.Active, true, 0).?;
                    _ = Memory.Paging.MapPage(
                        pd.?,
                        addr,
                        Memory.Paging.MapRead | (entry.flags & 2) | ((entry.flags & 1) << 2),
                        @intFromPtr(page.ptr) - 0xffff800000000000,
                    );
                    if (entry.fileSize > 0) {
                        @memcpy(@as([*]u8, @ptrFromInt(@intFromPtr(page.ptr)))[0..4096], @as([*]u8, @ptrFromInt(@intFromPtr(ptr) + @as(usize, @intCast(entry.offset))))[off..(off + 4096)]);
                        off += 4096;
                    }
                }
            }
        }
        return @as(usize, @intCast(header.programEntryPos));
    } else if (loadType == .Driver) {
        var i: usize = 0;
        while (i < header.shtEntryCount) : (i += 1) {
            var entry: *ELFSectionHeader = @as(*ELFSectionHeader, @ptrFromInt(@intFromPtr(ptr) + header.shtPos + (i * @as(usize, @intCast(header.shtEntrySize)))));
            if (entry.type == 8) {
                var size = if (entry.size & 0xFFF != 0) (entry.size & 0xFFFFFFFFFFFFF000) + 4096 else entry.size;
                entry.addr = @intFromPtr(Memory.Pool.PagedPool.AllocAnonPages(size).?.ptr);
            } else {
                entry.addr = @intFromPtr(ptr) + entry.offset;
            }
        }
        var drvrInfo: ?*devlib.RyuDriverInfo = null;
        i = 0;
        while (i < header.shtEntryCount) : (i += 1) {
            var entry: *ELFSectionHeader = @as(*ELFSectionHeader, @ptrFromInt(@intFromPtr(ptr) + header.shtPos + (i * @as(usize, @intCast(header.shtEntrySize)))));
            if (entry.type != 2) {
                continue;
            }
            var strTableHeader = @as(*ELFSectionHeader, @ptrFromInt(@intFromPtr(ptr) + header.shtPos + (@as(usize, @intCast(header.shtEntrySize)) * entry.link)));
            var sym: usize = 0;
            while (sym < (entry.size / @sizeOf(ELFSymbol))) : (sym += 1) {
                var symEntry = @as(*ELFSymbol, @ptrFromInt(entry.addr + (sym * @sizeOf(ELFSymbol))));
                if (symEntry.shndx > 0 and symEntry.shndx < 0xFF00) {
                    var e = @as(*ELFSectionHeader, @ptrFromInt(@intFromPtr(ptr) + header.shtPos + (symEntry.shndx * header.shtEntrySize)));
                    symEntry.value += e.addr;
                }
                if (symEntry.name != 0) {
                    var symbolCName = @as([*:0]u8, @ptrFromInt(strTableHeader.addr + symEntry.name));
                    var symbolName: []u8 = symbolCName[0..std.mem.len(symbolCName)];
                    if (std.mem.eql(u8, symbolName, "DriverInfo")) {
                        drvrInfo = @as(*devlib.RyuDriverInfo, @ptrFromInt(symEntry.value));
                    }
                }
            }
        }
        if (drvrInfo) |drvr| {
            if (Drivers.drvrHead == null) {
                Drivers.drvrHead = drvr;
                Drivers.drvrTail = drvr;
            } else {
                Drivers.drvrTail.?.next = drvr;
                drvr.prev = Drivers.drvrTail;
                Drivers.drvrTail = drvr;
            }
            drvr.baseAddr = @intFromPtr(ptr);
        } else {
            return ELFLoadError.NoDriverInfo;
        }
        i = 0;
        while (i < header.shtEntryCount) : (i += 1) {
            var entry: *ELFSectionHeader = @as(*ELFSectionHeader, @ptrFromInt(@intFromPtr(ptr) + header.shtPos + (i * @as(usize, @intCast(header.shtEntrySize)))));
            if (entry.type != 4) {
                continue;
            }
            var relTable = @as([*]ELFRela, @ptrFromInt(entry.addr))[0..(entry.size / @sizeOf(ELFRela))];
            var targetSection: *ELFSectionHeader = @as(*ELFSectionHeader, @ptrFromInt(@intFromPtr(ptr) + header.shtPos + (entry.info * @as(usize, @intCast(header.shtEntrySize)))));
            var symbolSection: *ELFSectionHeader = @as(*ELFSectionHeader, @ptrFromInt(@intFromPtr(ptr) + header.shtPos + (entry.link * @as(usize, @intCast(header.shtEntrySize)))));
            var symTable = @as([*]ELFSymbol, @ptrFromInt(symbolSection.addr))[0 .. symbolSection.size / @sizeOf(ELFSymbol)];
            for (0..relTable.len) |rela| {
                var target: usize = relTable[rela].offset +% targetSection.addr;
                var sym: usize = relTable[rela].info >> 32;
                switch (@as(ELFRelocType, @enumFromInt(@as(u32, @intCast(relTable[rela].info & 0xFFFFFFFF))))) {
                    .X86_64_64 => {
                        @as(*align(1) u64, @ptrFromInt(target)).* = @as(u64, @bitCast(relTable[rela].addend)) +% symTable[sym].value;
                    },
                    .X86_64_32 => {
                        @as(*align(1) u32, @ptrFromInt(target)).* = @as(u32, @intCast((@as(u64, @bitCast(relTable[rela].addend)) +% symTable[sym].value) & 0xFFFFFFFF));
                    },
                    .X86_64_PC32, .X86_64_PLT32 => {
                        @as(*align(1) u32, @ptrFromInt(target)).* = @as(u32, @intCast((@as(u64, @bitCast(relTable[rela].addend)) +% symTable[sym].value -% target) & 0xFFFFFFFF));
                    },
                    .X86_64_32S => {
                        @as(*align(1) i32, @ptrFromInt(target)).* = @as(i32, @bitCast(@as(u32, @intCast((@as(u64, @bitCast(relTable[rela].addend)) +% symTable[sym].value) & 0xFFFFFFFF))));
                    },
                    else => {
                        return ELFLoadError.UnrecognizedRelocation;
                    },
                }
            }
        }
    } else {
        return ELFLoadError.NotImplemented;
    }
    return null;
}
