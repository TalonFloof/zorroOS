const std = @import("std");
const Builder = std.Build;
const LazyPath = std.Build.LazyPath;
const GeneratedFile = std.Build.GeneratedFile;

const str = []const u8;

pub fn build(b: *Builder) !void {
    var query: std.Target.Query = .{
        .cpu_arch = .x86_64,
        .os_tag = .freestanding,
        .abi = .none,
    };

    const Features = std.Target.x86.Feature;
    query.cpu_features_sub.addFeature(@intFromEnum(Features.mmx));
    query.cpu_features_sub.addFeature(@intFromEnum(Features.sse));
    query.cpu_features_sub.addFeature(@intFromEnum(Features.sse2));
    query.cpu_features_sub.addFeature(@intFromEnum(Features.avx));
    query.cpu_features_sub.addFeature(@intFromEnum(Features.avx2));
    query.cpu_features_add.addFeature(@intFromEnum(Features.soft_float));
    const optimize = b.standardOptimizeOption(.{});
    const target = b.resolveTargetQuery(query);
    const kernel = b.addExecutable(.{
        .name = "Ryu",
        .root_source_file = b.path("kernel/main.zig"),
        .target = target,
        .optimize = optimize,
        .code_model = .kernel,
        .strip = false,
    });
    const limineMod = b.addModule("limine", .{
        .root_source_file = b.path("../limine-zig/limine.zig"),
        .target = target,
        .optimize = optimize,
        .red_zone = false,
        .strip = false,
    });
    const halMod = b.addModule("hal", .{
        .root_source_file = b.path("hal/HAL.zig"),
        .imports = &.{
            .{ .name = "limine", .module = limineMod },
        },
        .target = target,
        .optimize = optimize,
        .red_zone = false,
        .strip = false,
    });
    const memoryMod = b.addModule("memory", .{
        .root_source_file = b.path("memory/Memory.zig"),
        .imports = &.{
            .{ .name = "hal", .module = halMod },
        },
        .target = target,
        .optimize = optimize,
        .red_zone = false,
        .strip = false,
    });
    const executiveMod = b.addModule("executive", .{
        .root_source_file = b.path("executive/Executive.zig"),
        .target = target,
        .optimize = optimize,
        .red_zone = false,
        .strip = false,
    });
    const devlib = b.addModule("devlib", .{
        .root_source_file = b.path("../lib/devlib/devlib.zig"),
        .imports = &.{},
        .target = target,
        .optimize = optimize,
        .red_zone = false,
        .strip = false,
    });
    const fsMod = b.addModule("fs", .{
        .root_source_file = b.path("fs/VFS.zig"),
        .imports = &.{
            .{ .name = "devlib", .module = devlib },
        },
        .target = target,
        .optimize = optimize,
        .red_zone = false,
        .strip = false,
    });
    kernel.root_module.stack_protector = false;
    kernel.root_module.stack_check = false;
    kernel.root_module.red_zone = false;
    kernel.entry = std.Build.Step.Compile.Entry.disabled;
    kernel.setLinkerScript(b.path("hal/link_scripts/x86_64-Limine.ld"));
    kernel.setVerboseLink(true);
    kernel.root_module.addImport("limine", limineMod);
    kernel.root_module.addImport("hal", halMod);
    kernel.root_module.addImport("memory", memoryMod);
    kernel.root_module.addImport("executive", executiveMod);
    kernel.root_module.addImport("fs", fsMod);
    kernel.root_module.addImport("devlib", devlib);
    kernel.addObjectFile(b.path("_lowlevel.o"));

    b.getInstallStep().dependOn(&b.addInstallArtifact(kernel, .{
        .dest_dir = .{ .override = .{ .custom = "../" } },
    }).step);
}
