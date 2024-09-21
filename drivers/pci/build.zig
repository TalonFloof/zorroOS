const std = @import("std");
const Builder = std.Build;

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
    const driver = b.addObject(.{
        .name = "PCIDriver",
        .root_source_file = b.path("main.zig"),
        .target = target,
        .optimize = optimize,
        .code_model = std.builtin.CodeModel.large,
    });
    const devlib = b.addModule("devlib", .{
        .root_source_file = b.path("../../lib/devlib/devlib.zig"),
        .imports = &.{},
    });
    driver.entry = std.Build.Step.Compile.Entry.disabled;
    driver.root_module.addImport("devlib", devlib);
    b.default_step.dependOn(&b.addInstallArtifact(driver, .{
        .dest_dir = .{ .override = .{ .custom = "../../out/" } },
    }).step);
}
