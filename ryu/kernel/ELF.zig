const std = @import("std");

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

const ELFLoadError = error{
    BadMagic,
    Not64Bit,
    IncorrectArcitecture,
    NotRelocatable,
    NotDynamic,
    NotExecutable,
    UnrecognizedRelocation,
};

const ELFLoadType = enum {
    Normal,
    Driver,
    Library,
};

pub fn LoadELF(ptr: *void, loadType: ELFLoadType) ELFLoadError!void {
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
}
