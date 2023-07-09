pub const PCIInterface = extern struct {
    readU8: *const fn (u8, u8, u8, u16) callconv(.C) u8,
    readU16: *const fn (u8, u8, u8, u16) callconv(.C) u16,
    readU32: *const fn (u8, u8, u8, u16) callconv(.C) u32,
    writeU8: *const fn (u8, u8, u8, u16, u8) callconv(.C) void,
    writeU16: *const fn (u8, u8, u8, u16, u16) callconv(.C) void,
    writeU32: *const fn (u8, u8, u8, u16, u32) callconv(.C) void,
    readBar: *const fn (u8, u8, u8, u8) callconv(.C) u64,
    searchCapability: *const fn (u8, u8, u8, u8) callconv(.C) u16,
    acquireIRQ: *const fn (u8, u8, u8, *const fn (u16) callconv(.C) void) callconv(.C) u16,
    getDevices: *const fn () callconv(.C) *PCIDevice,
};
pub const PCIDevice = extern struct {
    next: ?*PCIDevice,
    bus: u8,
    slot: u8,
    func: u8,
    vendor: u16,
    device: u16,
    class: u8,
    subclass: u8,
    progif: u8,
};
