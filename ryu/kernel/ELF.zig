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
    AttWE32100 = 0x01,
    Sparc = 0x02,
    Intelx86 = 0x03,
    Motorola68000 = 0x04,
    Motorola88000 = 0x05,
    IntelMCU = 0x06,
    Intel80860 = 0x07,
    Mips = 0x08,
    IBMSystem370 = 0x09,
    MipsRS3000LE = 0x0a,
    HpPARISC = 0x0e,
    Intel80960 = 0x13,
    PowerPC32 = 0x14,
    PowerPC64 = 0x15,
    S390x = 0x16,
    IbmSpuSpc = 0x17,
    NecV800 = 0x24,
    FujisuFR20 = 0x25,
    TrwRH32 = 0x26,
    MotorolaRCE = 0x27,
    ARM32 = 0x28,
    DigitalAlpha = 0x29,
    SuperH = 0x2a,
    SparcV9 = 0x2b,
    SiemensTriCore = 0x2c,
    ArgonautRISC = 0x2d,
    HitachiH8_300 = 0x2e,
    HitachiH8_300H = 0x2f,
    HitachiH8S = 0x30,
    HitachiH8_500 = 0x31,
    IntelItanium = 0x32,
    StanfordMIPSX = 0x33,
    MotorolaColdFire = 0x34,
    MotorolaM68HC12 = 0x35,
    FujitsuMMAMediaAccel = 0x36,
    SiemensPCP = 0x37,
    SonyNCPU = 0x38,
    DensoNDR1 = 0x39,
    MotorolaStarCore = 0x3a,
    ToyotaME16 = 0x3b,
    STMicroelecST100 = 0x3c,
    ALCTinyJ = 0x3d,
    AMDx86_64 = 0x3e,
    SonyDSP = 0x3f,
    DigitalPDP10 = 0x40,
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
    DigitalVAX = 0x4b,
    AxisCom32 = 0x4c,
    InfineonTech32 = 0x4d,
    Element14DSP = 0x4e,
    LSILogic = 0x4f,
    TMS320C6000 = 0x8c,
    MCSTElbrusE2k = 0xaf,
    ARM64 = 0xb7,
    ZilogZ80 = 0xdc, // Our lord and savior, the Zilog Z80 :3
    RISCV = 0xf3,
    BerkeleyPacketFilter = 0xf7,
    WDC65C816 = 0x101,
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

//#define R_X86_64_64 1
//#define R_X86_64_32 10
//#define R_X86_64_32S 11
//#define R_X86_64_PC32 2
//#define R_X86_64_PLT32 4
//#define R_X86_64_RELATIVE 8

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
    Library,
};

pub fn LoadELF(ptr: *void, loadType: ELFLoadType) ELFLoadError!?usize {
    var header: *ELFHeader = @ptrCast(*ELFHeader, @alignCast(@alignOf(ELFHeader), ptr));
    if (header.magic != 0x464C457F) {
        return ELFLoadError.BadMagic;
    }
    if (header.bits != 2) {
        return ELFLoadError.Not64Bit;
    }
    if (header.objType != .Relocatable and loadType == .Driver) {
        return ELFLoadError.NotRelocatable;
    } else if (header.objType != .Shared and loadType == .Library) {
        return ELFLoadError.NotDynamic;
    } else if (header.objType != .Executable and loadType == .Normal) {
        return ELFLoadError.NotExecutable;
    }
    if (loadType == .Driver) {
        var i: usize = 0;
        while (i < header.shtEntryCount) : (i += 1) {
            var entry: *ELFSectionHeader = @intToPtr(*ELFSectionHeader, @ptrToInt(ptr) + header.shtPos + (i * @intCast(usize, header.shtEntrySize)));
            if (entry.type == 8) {
                var size = if (entry.size & 0xFFF != 0) (entry.size & 0xFFFFFFFFFFFFF000) + 4096 else entry.size;
                entry.addr = @ptrToInt(Memory.Pool.PagedPool.Alloc(size).?.ptr);
            } else {
                entry.addr = @ptrToInt(ptr) + entry.offset;
            }
        }
        var drvrInfo: ?*devlib.RyuDriverInfo = null;
        i = 0;
        while (i < header.shtEntryCount) : (i += 1) {
            var entry: *ELFSectionHeader = @intToPtr(*ELFSectionHeader, @ptrToInt(ptr) + header.shtPos + (i * @intCast(usize, header.shtEntrySize)));
            if (entry.type != 2) {
                continue;
            }
            var strTableHeader = @intToPtr(*ELFSectionHeader, @ptrToInt(ptr) + header.shtPos + (@intCast(usize, header.shtEntrySize) * entry.link));
            var sym: usize = 0;
            while (sym < (entry.size / @sizeOf(ELFSymbol))) : (sym += 1) {
                var symEntry = @intToPtr(*ELFSymbol, entry.addr + (sym * @sizeOf(ELFSymbol)));
                if (symEntry.shndx > 0 and symEntry.shndx < 0xFF00) {
                    var e = @intToPtr(*ELFSectionHeader, @ptrToInt(ptr) + header.shtPos + (symEntry.shndx * header.shtEntrySize));
                    symEntry.value += e.addr;
                }
                if (symEntry.name != 0) {
                    var symbolCName = @intToPtr([*:0]u8, strTableHeader.addr + symEntry.name);
                    var symbolName: []u8 = symbolCName[0..std.mem.len(symbolCName)];
                    if (std.mem.eql(u8, symbolName, "DriverInfo")) {
                        drvrInfo = @intToPtr(*devlib.RyuDriverInfo, symEntry.value);
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
            drvr.baseAddr = @ptrToInt(ptr);
        } else {
            return ELFLoadError.NoDriverInfo;
        }
        i = 0;
        while (i < header.shtEntryCount) : (i += 1) {
            var entry: *ELFSectionHeader = @intToPtr(*ELFSectionHeader, @ptrToInt(ptr) + header.shtPos + (i * @intCast(usize, header.shtEntrySize)));
            if (entry.type != 4) {
                continue;
            }
            var relTable = @intToPtr([*]ELFRela, entry.addr)[0..(entry.size / @sizeOf(ELFRela))];
            var targetSection: *ELFSectionHeader = @intToPtr(*ELFSectionHeader, @ptrToInt(ptr) + header.shtPos + (entry.info * @intCast(usize, header.shtEntrySize)));
            var symbolSection: *ELFSectionHeader = @intToPtr(*ELFSectionHeader, @ptrToInt(ptr) + header.shtPos + (entry.link * @intCast(usize, header.shtEntrySize)));
            var symTable = @intToPtr([*]ELFSymbol, symbolSection.addr)[0 .. symbolSection.size / @sizeOf(ELFSymbol)];
            for (0..relTable.len) |rela| {
                var target: usize = relTable[rela].offset +% targetSection.addr;
                var sym: usize = relTable[rela].info >> 32;
                switch (@intToEnum(ELFRelocType, @intCast(u32, relTable[rela].info & 0xFFFFFFFF))) {
                    .X86_64_64 => {
                        @intToPtr(*align(1) u64, target).* = @bitCast(u64, relTable[rela].addend) +% symTable[sym].value;
                    },
                    .X86_64_32 => {
                        @intToPtr(*align(1) u32, target).* = @intCast(u32, @bitCast(u64, relTable[rela].addend) +% symTable[sym].value);
                    },
                    .X86_64_PC32, .X86_64_PLT32 => {
                        @intToPtr(*align(1) u32, target).* = @intCast(u32, @bitCast(u64, relTable[rela].addend) +% symTable[sym].value -% target);
                    },
                    .X86_64_32S => {
                        @intToPtr(*align(1) i32, target).* = @bitCast(i32, @intCast(u32, (@bitCast(u64, relTable[rela].addend) +% symTable[sym].value) & 0xFFFFFFFF));
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
