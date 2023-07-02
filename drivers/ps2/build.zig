const std = @import("std");
const Builder = std.build.Builder;

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
    const driver = b.addObject(.{
        .name = "PS2Driver",
        .root_source_file = .{ .path = "main.zig" },
        .target = target,
        .optimize = optimize,
    });
    const devlib = b.createModule(.{
        .source_file = .{ .path = "../../lib/devlib/devlib.zig" },
        .dependencies = &.{},
    });
    driver.code_model = std.builtin.CodeModel.large;
    driver.addModule("devlib", devlib);
    driver.override_dest_dir = .{ .custom = "../../out/" };
    b.installArtifact(driver);
}
