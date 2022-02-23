const std = @import("std");

const glfw = @import("glfw");
const gl = @import("gl");
const glhelp = @import("glhelp.zig");

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
    _ = width;
    _ = height;
    //gl.viewport(0, 0, @intCast(gl.GLint, width), @intCast(gl.GLint, height));
}

const vertices : []const f32 = &[_]f32 {
    1.0, 1.0, 0.0, 0.0,
    1.0, -1.0, 0.0, 1.0,
    -1.0, -1.0, 1.0, 1.0,
    -1.0, 1.0, 1.0, 0.0,
};

const indices : []const gl.GLuint = &[_]gl.GLuint {
    0,1,3,
    1,2,3,
};

var vertex_buffer_object : gl.GLuint = undefined;
var vertex_array_object : gl.GLuint = undefined;
var element_buffer_object : gl.GLuint = undefined;


pub const Context = struct {
    glfw_window : glfw.Window,
    game_buffer : gl.GLuint = 0,
    game_texture : gl.GLuint = 0,
    game_renderbuffer : gl.GLuint = 0,

    screen_shader : gl.GLuint = 0,

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

        // buffer
        gl.genFramebuffers(1, &self.game_buffer);
        gl.bindFramebuffer(gl.FRAMEBUFFER, self.game_buffer);

        // texture
        gl.genTextures(1, &self.game_texture);
        gl.bindTexture(gl.TEXTURE_2D, self.game_texture);

        gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGB, 640, 480, 0, gl.RGB, gl.UNSIGNED_BYTE, null);

        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);

        gl.bindTexture(gl.TEXTURE_2D, 0);

        //bind texture to buffer
        gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, self.game_texture, 0);


        // renderbuffer
        gl.genRenderbuffers(1, &self.game_renderbuffer);
        gl.bindRenderbuffer(gl.RENDERBUFFER, self.game_renderbuffer);
        gl.renderbufferStorage(gl.RENDERBUFFER, gl.DEPTH24_STENCIL8, 640, 480);
        gl.bindRenderbuffer(gl.RENDERBUFFER, 0);

        gl.framebufferRenderbuffer(gl.FRAMEBUFFER, gl.DEPTH_STENCIL_ATTACHMENT, gl.RENDERBUFFER, self.game_renderbuffer);

        if (gl.checkFramebufferStatus(gl.FRAMEBUFFER) != gl.FRAMEBUFFER_COMPLETE)
            return error.FramebufferInitFailed;

        gl.bindFramebuffer(gl.FRAMEBUFFER, 0);


        // debug
        self.screen_shader = try glhelp.buildProgram(@embedFile("screenShader.vert"), @embedFile("screenShader.frag"));
        errdefer gl.deleteProgram(self.screen_shader);

        gl.genVertexArrays(1, &vertex_array_object);

        gl.genBuffers(1, &vertex_buffer_object);
        gl.genBuffers(1, &element_buffer_object);


        gl.bindVertexArray(vertex_array_object);

        gl.bindBuffer(gl.ARRAY_BUFFER, vertex_buffer_object);
        gl.bufferData(gl.ARRAY_BUFFER, vertices.len * @sizeOf(f32), vertices.ptr, gl.STATIC_DRAW);

        gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, element_buffer_object);
        gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, indices.len * @sizeOf(gl.GLuint), indices.ptr, gl.STATIC_DRAW);
        

        gl.vertexAttribPointer(0, 2, gl.FLOAT, gl.FALSE, 4 * @sizeOf(f32), null);
        gl.vertexAttribPointer(1, 2, gl.FLOAT, gl.FALSE, 4 * @sizeOf(f32), @intToPtr(*anyopaque, 2*@sizeOf(f32)));

        gl.enableVertexAttribArray(0);
        gl.enableVertexAttribArray(1);

        gl.bindVertexArray(0);

        return self;
    }

    pub fn run(self: *Context, callback : fn(ctxt : Context) anyerror!void) !void
    {
        std.log.info("{d: >7.4} starting main loop ...", .{glfw.getTime()});
        var show_demo_window : bool = true;
        while (!self.glfw_window.shouldClose()) {

            try glfw.pollEvents();

            gl.clearColor(0.7, 0.2, 0.1, 1.0);
            gl.clear(gl.COLOR_BUFFER_BIT);

            c.ImGui_ImplOpenGL3_NewFrame();
            c.ImGui_ImplGlfw_NewFrame();

            c.igNewFrame();

            if (show_demo_window)
            {
                c.igShowDemoWindow(&show_demo_window);
            }


            gl.bindFramebuffer(gl.FRAMEBUFFER, self.game_buffer);
            try callback(self.*);
            gl.bindFramebuffer(gl.FRAMEBUFFER, 0);

            _ = c.igBegin("Scene Window", null, 0);
            c.igImage(@intToPtr(*anyopaque, self.game_texture), .{.x = 640, .y =480}, .{.x = 0, .y = 1}, .{.x = 1, .y = 0}, .{.x = 1.0, .y = 1.0, .z = 1.0, .w = 1.0}, .{.x = 1.0, .y = 1.0, .z = 1.0, .w = 0.0});

            c.igEnd();

            gl.useProgram(self.screen_shader);
            gl.bindVertexArray(vertex_array_object);
            gl.bindTexture(gl.TEXTURE_2D, self.game_texture);
            gl.drawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, null);

            gl.bindTexture(gl.TEXTURE_2D, 0);

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


