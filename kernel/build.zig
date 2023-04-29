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
    target.cpu_features_sub.addFeature(@enumToInt(Features.mmx));
    target.cpu_features_sub.addFeature(@enumToInt(Features.sse));
    target.cpu_features_sub.addFeature(@enumToInt(Features.sse2));
    target.cpu_features_sub.addFeature(@enumToInt(Features.avx));
    target.cpu_features_sub.addFeature(@enumToInt(Features.avx2));
    target.cpu_features_add.addFeature(@enumToInt(Features.soft_float));
    const optimize = b.standardOptimizeOption(.{});
    const kernel = b.addExecutable(.{
        .name = "ZorroKernel",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    const limineMod = b.createModule(.{
        .source_file = .{ .path = "../limine-zig/limine.zig" },
    });
    const nativeMod = b.createModule(.{
        .source_file = .{ .path = "arch/x86_64/main.zig" },
        .dependencies = &.{
            .{ .name = "limine", .module = limineMod },
        },
    });
    kernel.addModule("limine", limineMod);
    kernel.addModule("native", nativeMod);
    kernel.addObjectFile("arch/x86_64/isr.o");
    kernel.code_model = .kernel;
    kernel.setLinkerScriptPath(.{ .path = "link_scripts/x86_64-Limine.ld" });
    kernel.override_dest_dir = .{ .custom = "../" };
    b.installArtifact(kernel);
}
