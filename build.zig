const std = @import("std");
const glfw = @import("libs/mach-glfw/build.zig");

pub fn build(b: *std.build.Builder) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    // const exe_options = b.addOptions();

    // exe_options.addOption([]const u8, "lesson", b.option([]const u8, "lesson", "Lesson file to build (ex : '01')") orelse "01");
    
    const exe = b.addExecutable("ZigOpengl", "src/main.zig");
    exe.setTarget(target);
    exe.setBuildMode(mode);

    // exe.addOptions("build_options", exe_options);

    exe.addPackagePath("glfw", "libs/mach-glfw/src/main.zig");
    exe.addPackagePath("gl", "libs/gl/gl_3v3.zig");


    // Imgui Part

    const cimgui_path = "libs/imgui/";
    const imgui_path = cimgui_path ++ "imgui/";
    exe.addCSourceFiles(
        &[_][]const u8{
            cimgui_path ++"cimgui.cpp",
            imgui_path ++ "imgui.cpp",
            imgui_path ++ "imgui_demo.cpp",
            imgui_path ++ "imgui_draw.cpp",
            imgui_path ++ "imgui_impl_glfw.cpp",
            imgui_path ++ "imgui_impl_opengl3.cpp",
            imgui_path ++ "imgui_tables.cpp",
            imgui_path ++ "imgui_widgets.cpp",
        },
        &[_][]const u8{});

    exe.addIncludeDir(cimgui_path);
    exe.linkLibCpp();
    exe.linkLibC();

    exe.addIncludePath("libs/stb");
    exe.addCSourceFile("libs/stb/stbi_impl.c", &[_][]const u8{"-std=c99"});

    glfw.link(b,exe, .{});
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_tests = b.addTest("src/main.zig");
    exe_tests.setTarget(target);
    exe_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&exe_tests.step);
}
