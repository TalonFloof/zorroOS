const std = @import("std");
const Builder = std.build.Builder;
const LazyPath = std.build.LazyPath;
const GeneratedFile = std.build.GeneratedFile;

const str = []const u8;

pub fn build(b: *Builder) !void {
    var target: std.zig.CrossTarget = .{
        .cpu_arch = .x86_64,
        .os_tag = .freestanding,
        .abi = .none,
    };

    const Features = std.Target.x86.Feature;
    target.cpu_features_sub.addFeature(@intFromEnum(Features.mmx));
    target.cpu_features_sub.addFeature(@intFromEnum(Features.sse));
    target.cpu_features_sub.addFeature(@intFromEnum(Features.sse2));
    target.cpu_features_sub.addFeature(@intFromEnum(Features.avx));
    target.cpu_features_sub.addFeature(@intFromEnum(Features.avx2));
    target.cpu_features_add.addFeature(@intFromEnum(Features.soft_float));
    const optimize = b.standardOptimizeOption(.{});
    const kernel = b.addExecutable(.{
        .name = "Ryu",
        .root_source_file = .{ .path = "kernel/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    const limineMod = b.createModule(.{
        .source_file = .{ .path = "../limine-zig/limine.zig" },
    });
    const halMod = b.createModule(.{
        .source_file = .{ .path = "hal/HAL.zig" },
        .dependencies = &.{
            .{ .name = "limine", .module = limineMod },
        },
    });
    const memoryMod = b.createModule(.{
        .source_file = .{ .path = "memory/Memory.zig" },
        .dependencies = &.{
            .{ .name = "hal", .module = halMod },
        },
    });
    const executiveMod = b.createModule(.{ .source_file = .{ .path = "executive/Executive.zig" } });
    const devlib = b.createModule(.{ .source_file = .{ .path = "../lib/devlib/devlib.zig" }, .dependencies = &.{} });
    const fsMod = b.createModule(.{
        .source_file = .{ .path = "fs/VFS.zig" },
        .dependencies = &.{
            .{ .name = "devlib", .module = devlib },
        },
    });
    kernel.addModule("limine", limineMod);
    kernel.addModule("hal", halMod);
    kernel.addModule("memory", memoryMod);
    kernel.addModule("executive", executiveMod);
    kernel.addModule("fs", fsMod);
    kernel.addModule("devlib", devlib);
    kernel.addObjectFile(LazyPath.relative("_lowlevel.o"));
    kernel.code_model = .kernel;
    kernel.setLinkerScriptPath(.{ .path = "hal/link_scripts/x86_64-Limine.ld" });
    b.getInstallStep().dependOn(&b.addInstallArtifact(kernel, .{
        .dest_dir = .{ .override = .{ .custom = "../" } },
    }).step);
}
