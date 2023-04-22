const std = @import("std");

pub const Entry = packed struct(u64) {
    limitLow: u16,
    baseLow: u16,
    baseMid: u8,
    access: packed struct(u8) {
        accessed: bool,
        readWrite: bool,
        direction: bool,
        executable: bool,
        codeData: bool,
        dpl: u2,
        present: bool,
    },
    limitHigh: u4,
    reserved: u1 = 0,
    longMode: bool,
    sizeFlag: bool,
    granularity: bool,
    baseHigh: u8 = 0,
};

pub const TSSEntry = packed struct {
    gdtEntry: Entry,
    baseUpper: u32,
    reserved: u32 = 0,
};
