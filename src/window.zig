const std = @import("std");

const glfw = @import("glfw");
const gl = @import("gl");

const c = @cImport({
    @cDefine("CIMGUI_DEFINE_ENUMS_AND_STRUCTS", "1");
    @cInclude("cimgui.h");
    @cInclude("imgui/imgui_impl_opengl3.h");
    @cInclude("imgui/imgui_impl_glfw.h");
}
);

fn getProcAdress(dummy : ?*anyopaque, proc_name : [:0]const u8) ?*const anyopaque
{
    _ = dummy;
    return glfw.getProcAddress(proc_name);
}

fn onResize(window:glfw.Window, width:u32, height:u32) void
{
    _ = window;
    gl.viewport(0, 0, @intCast(gl.GLint, width), @intCast(gl.GLint, height));
}

pub const Context = struct {
    glfw_window : glfw.Window,

    pub fn init() !Context
    {
        try glfw.init(.{});
        errdefer glfw.terminate();

        var self : Context = undefined;

        std.log.info("{d: >7.4} init window ...", .{glfw.getTime()});
        self.glfw_window = try glfw.Window.create(640, 480, "Learn Opengl", null, null, 
        .{
            .opengl_profile = .opengl_core_profile,
            .context_version_major = 3,
            .context_version_minor = 3,
        });
        errdefer self.glfw_window.destroy();

        glfw.Window.setFramebufferSizeCallback(self.glfw_window, onResize);

        std.log.info("{d: >7.4} starting opengl context ...", .{glfw.getTime()});
        try glfw.makeContextCurrent(self.glfw_window);

        std.log.info("{d: >7.4} loading opengl ...", .{glfw.getTime()});
        try gl.load(@as(?*anyopaque, null), getProcAdress);

        gl.viewport(0, 0, 640, 480);

        _ = c.igCreateContext(null);
        var io : [*c]c.ImGuiIO = c.igGetIO();
        _ = io;

        c.igStyleColorsDark(null);

        _ = c.ImGui_ImplGlfw_InitForOpenGL(@ptrCast(*c.GLFWwindow, self.glfw_window.handle), true);
        _ = c.ImGui_ImplOpenGL3_Init("#version 130");

        return self;
    }

    pub fn run(self: Context, callback : fn(ctxt : Context) anyerror!void) !void
    {
        std.log.info("{d: >7.4} starting main loop ...", .{glfw.getTime()});
        var show_demo_window : bool = true;
        while (!self.glfw_window.shouldClose()) {

            try glfw.pollEvents();

            c.ImGui_ImplOpenGL3_NewFrame();
            c.ImGui_ImplGlfw_NewFrame();

            c.igNewFrame();

            if (show_demo_window)
            {
                c.igShowDemoWindow(&show_demo_window);
            }


        
            try callback(self);

            c.igRender();
            c.ImGui_ImplOpenGL3_RenderDrawData(c.igGetDrawData());

            try glfw.Window.swapBuffers(self.glfw_window);
        }
    }

    pub fn deinit(self : Context) void
    {
        self.glfw_window.destroy();
        glfw.terminate();
    }
};


