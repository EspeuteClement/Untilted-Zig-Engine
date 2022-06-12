const std = @import("std");
const glfw = @import("libs/mach-glfw/build.zig");

const with_imgui = false;
const test_packing_data = false;

pub fn build(b: *std.build.Builder) void {

    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const exe_options = b.addOptions();
    exe_options.addOption(bool, "with_imgui", with_imgui);
    exe_options.addOption(bool, "test_packing_data", test_packing_data);


    // const exe_options = b.addOptions();

    // exe_options.addOption([]const u8, "lesson", b.option([]const u8, "lesson", "Lesson file to build (ex : '01')") orelse "01");

    const main_exe = makeExe(b, target, mode, exe_options, "ZigOpengl", "src/main.zig", "run", "Run the app");
    const asset_builder_exe = makeExe(b, target, mode, exe_options, "AssetBuilder", "src/asset_manager.zig", "run-asset", "Run the asset builder");
    const png2raw = makeExe(b, target, mode, exe_options, "png2raw", "src/png2raw.zig", "run-png2raw", "Run png2raw");

    _ = main_exe;
    _ = asset_builder_exe;
    _ = png2raw;

    const exe_tests = b.addTest("src/main.zig");
    configure(exe_tests, b, target, mode, exe_options);

    const asset_tests = b.addTest("src/asset_manager.zig");
    configure(asset_tests, b, target, mode, exe_options);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&exe_tests.step);

    const test_asset_step = b.step("test-asset", "Run unit tests for asset packer");
    test_asset_step.dependOn(&asset_tests.step);
}

fn makeExe(b: *std.build.Builder, target: std.zig.CrossTarget, mode: std.builtin.Mode, exe_options: *std.build.OptionsStep, name: []const u8, root: []const u8, step_name: []const u8, step_desc: []const u8) struct { exe: *std.build.LibExeObjStep, run_cmd: *std.build.RunStep, run_step: *std.build.Step } {
    const exe = b.addExecutable(name, root);
    configure(exe, b, target, mode, exe_options);
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step(step_name, step_desc);
    run_step.dependOn(&run_cmd.step);

    return .{ .exe = exe, .run_cmd = run_cmd, .run_step = run_step };
}

fn configure(step: anytype, b: *std.build.Builder, target: std.zig.CrossTarget, mode: std.builtin.Mode, options: *std.build.OptionsStep) void {
    _ = b;
    step.setTarget(target);
    step.setBuildMode(mode);

    // step.addOptions("build_options", step_options);
    step.addOptions("build_options", options);

    step.addPackagePath("glfw", "libs/mach-glfw/src/main.zig");
    step.addPackagePath("gl", "libs/gl/gl_3v3.zig");
    step.addPackagePath("zigimg", "libs/zigimg/zigimg.zig");

    // Imgui Part
    const cimgui_path = "libs/imgui/";
    if (with_imgui) {
        const imgui_path = cimgui_path ++ "imgui/";
        step.addCSourceFiles(&[_][]const u8{
            cimgui_path ++ "cimgui.cpp",
            imgui_path ++ "imgui.cpp",
            imgui_path ++ "imgui_demo.cpp",
            imgui_path ++ "imgui_draw.cpp",
            imgui_path ++ "imgui_impl_glfw.cpp",
            imgui_path ++ "imgui_impl_opengl3.cpp",
            imgui_path ++ "imgui_tables.cpp",
            imgui_path ++ "imgui_widgets.cpp",
        }, &[_][]const u8{});
        step.linkLibCpp();
    }

    step.addIncludeDir(cimgui_path);
    step.linkLibC();

    step.addIncludePath("libs/stb");
    step.addCSourceFile("libs/stb/stbi_impl.c", &[_][]const u8{"-std=c99"});
    step.addCSourceFile("libs/stb/stb_rect_pack.c", &[_][]const u8{"-std=c99"});

    glfw.link(b, step, .{});
}
