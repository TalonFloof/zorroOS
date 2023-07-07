pub const PCIInterface = extern struct {
    readU8: *const fn (u8, u8, u8, u16) callconv(.C) u8,
    readU16: *const fn (u8, u8, u8, u16) callconv(.C) u16,
    readU32: *const fn (u8, u8, u8, u16) callconv(.C) u32,
    writeU8: *const fn (u8, u8, u8, u16, u8) callconv(.C) void,
    writeU16: *const fn (u8, u8, u8, u16, u16) callconv(.C) void,
    writeU32: *const fn (u8, u8, u8, u16, u32) callconv(.C) void,
};
