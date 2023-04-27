const std = @import("std");
const limine = @import("limine");
const alloc = @import("root").alloc;

export var memmap_request: limine.MemoryMapRequest = .{};

pub fn initialize() void {
    var memTotal: u64 = 0;
    var kernelUsed: u64 = 0;
    var bootldrUsed: u64 = 0;
    var acpiUsed: u64 = 0;
    var i: usize = 0;
    if (memmap_request.response) |memmap_response| {
        for (memmap_response.entries()) |entry| {
            var entryKind: []const u8 = "Unknown";
            switch (entry.kind) {
                .usable => {
                    alloc.free(@intToPtr([*]u8, entry.base)[0..entry.length]);
                    i += 1;
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
        }
    } else {
        @panic("Bootloader did not provide a valid memory map!");
    }
    std.log.debug("{d}MB\n\n", .{(memTotal / 1024) / 1024});
}
