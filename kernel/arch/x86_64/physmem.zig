const std = @import("std");
const limine = @import("limine");

export var memmap_request: limine.MemoryMapRequest = .{};

extern const _TEXT_START_: *allowzero void;
extern const _TEXT_END_: *allowzero void;
extern const _RODATA_START_: *allowzero void;
extern const _RODATA_END_: *allowzero void;
extern const _DATA_START_: *allowzero void;
extern const _BSS_END_: *allowzero void;

pub fn initialize() void {
    var memTotal: u64 = 0;
    var kernelUsed: u64 = 0;
    var bootldrUsed: u64 = 0;
    var acpiUsed: u64 = 0;
    if (memmap_request.response) |memmap_response| {
        for (memmap_response.entries()) |entry| {
            var entryKind: []const u8 = "Unknown";
            switch (entry.kind) {
                .usable => {
                    memTotal += entry.length;
                    entryKind = "Usable Block";
                },
                .reserved => {
                    entryKind = "Reserved Block";
                },
                .acpi_reclaimable => {
                    memTotal += entry.length;
                    acpiUsed += entry.length;
                    entryKind = "ACPI Reclaimable Block";
                },
                .acpi_nvs => {
                    entryKind = "ACPI Non-Volatile Storage";
                },
                .bad_memory => {
                    entryKind = "Bad Memory Block";
                },
                .bootloader_reclaimable => {
                    memTotal += entry.length;
                    bootldrUsed += entry.length;
                    entryKind = "Bootloader Reclaimable Block";
                },
                .kernel_and_modules => {
                    memTotal += entry.length;
                    kernelUsed += entry.length;
                    entryKind = "zorroOS Kernel Block";
                },
                .framebuffer => {
                    entryKind = "Framebuffer";
                },
            }
            std.log.debug("Limine MemMap: [mem 0x{x:0>16}-0x{x:0>16}] {s}\n", .{ entry.base, entry.base + (entry.length - 1), entryKind });
        }
    } else {
        @panic("Bootloader did not provide a valid memory map!");
    }
    std.log.info("Memory: {d}K/{d}K available ({d}K acpi data, {d}K boot data, {d}K kernel, {d}K kernel code, {d}K rodata, {d}K rwdata)", .{
        (memTotal - (bootldrUsed + acpiUsed + kernelUsed)) / 1024,
        memTotal / 1024,
        acpiUsed / 1024,
        bootldrUsed / 1024,
        kernelUsed / 1024,
        (@ptrToInt(&_TEXT_END_) - @ptrToInt(&_TEXT_START_)) / 1024,
        (@ptrToInt(&_RODATA_END_) - @ptrToInt(&_RODATA_START_)) / 1024,
        (@ptrToInt(&_BSS_END_) - @ptrToInt(&_DATA_START_)) / 1024,
    });
}
