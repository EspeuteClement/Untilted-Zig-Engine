const std = @import("std");
const Allocator = std.mem.Allocator;

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

    var self : *Context.Data = window.getUserPointer(Context.Data) orelse @panic("missing userptr");
    
    self.config.window_width = width;
    self.config.window_height = height;
    //gl.viewport(0, 0, @intCast(gl.GLint, width), @intCast(gl.GLint, height));
}

const vertices : []const f32 = &[_]f32 {
    1.0, 1.0, 0.0, 1.0,
    1.0, -1.0, 0.0, 0.0,
    -1.0, -1.0, 1.0, 0.0,
    -1.0, 1.0, 1.0, 1.0,
};

const indices : []const gl.GLuint = &[_]gl.GLuint {
    0,1,3,
    1,2,3,
};

var vertex_buffer_object : gl.GLuint = undefined;
var vertex_array_object : gl.GLuint = undefined;
var element_buffer_object : gl.GLuint = undefined;


pub const Context = struct {
    data : *Data = undefined,
    allocator : Allocator = undefined,

    pub const Data = struct {
        glfw_window : glfw.Window = undefined,
        game_buffer : gl.GLuint = 0,
        game_texture : gl.GLuint = 0,
        game_renderbuffer : gl.GLuint = 0,

        screen_shader : gl.GLuint = 0,

        config : Config = Config{},

        current_zoom : u8 = 1,

        const Config = struct {
            game_width : u32 = 640,
            game_height : u32 = 480,

            window_width : u32 = 800,
            window_height : u32 = 600,
        };
    };

    fn initGameRenderbuffer(self : *Context) !void
    {

        // buffer
        gl.genFramebuffers(1, &self.data.game_buffer);
        gl.bindFramebuffer(gl.FRAMEBUFFER, self.data.game_buffer);

        // texture
        gl.genTextures(1, &self.data.game_texture);
        gl.bindTexture(gl.TEXTURE_2D, self.data.game_texture);

        gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGB, @intCast(c_int, self.data.config.game_width), @intCast(c_int, self.data.config.game_height), 0, gl.RGB, gl.UNSIGNED_BYTE, null);

        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);

        gl.bindTexture(gl.TEXTURE_2D, 0);

        //bind texture to buffer
        gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, self.data.game_texture, 0);


        // renderbuffer
        gl.genRenderbuffers(1, &self.data.game_renderbuffer);
        gl.bindRenderbuffer(gl.RENDERBUFFER, self.data.game_renderbuffer);
        gl.renderbufferStorage(gl.RENDERBUFFER, gl.DEPTH24_STENCIL8, @intCast(c_int, self.data.config.game_width), @intCast(c_int, self.data.config.game_height));
        gl.bindRenderbuffer(gl.RENDERBUFFER, 0);

        gl.framebufferRenderbuffer(gl.FRAMEBUFFER, gl.DEPTH_STENCIL_ATTACHMENT, gl.RENDERBUFFER, self.data.game_renderbuffer);

        if (gl.checkFramebufferStatus(gl.FRAMEBUFFER) != gl.FRAMEBUFFER_COMPLETE)
            return error.FramebufferInitFailed;

        gl.bindFramebuffer(gl.FRAMEBUFFER, 0);
    }

    fn initFullscreenQuadVAO(self : *Context) !void
    {
        self.data.screen_shader = try glhelp.buildProgram(@embedFile("screenShader.vert"), @embedFile("screenShader.frag"));
        errdefer gl.deleteProgram(self.data.screen_shader);

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
    }

    pub fn init(allocator : Allocator) !Context
    {
        try glfw.init(.{});
        errdefer glfw.terminate();

        var self : Context = undefined;

        self.data = try allocator.create(Data);
        errdefer allocator.destroy(self.data);

        self.data.* = Data{};

        self.allocator = allocator;

        std.log.info("{d: >7.4} init window ...", .{glfw.getTime()});
        self.data.glfw_window = try glfw.Window.create(self.data.config.game_width, self.data.config.game_height, "Learn Opengl", null, null, 
        .{
            .opengl_profile = .opengl_core_profile,
            .context_version_major = 3,
            .context_version_minor = 3,
        });
        errdefer self.data.glfw_window.destroy();

        
        glfw.Window.setUserPointer(self.data.glfw_window, self.data);
        glfw.Window.setFramebufferSizeCallback(self.data.glfw_window, onResize);

        std.log.info("{d: >7.4} starting opengl context ...", .{glfw.getTime()});
        try glfw.makeContextCurrent(self.data.glfw_window);

        std.log.info("{d: >7.4} loading opengl ...", .{glfw.getTime()});
        try gl.load(@as(?*anyopaque, null), getProcAdress);


        _ = c.igCreateContext(null);
        var io : [*c]c.ImGuiIO = c.igGetIO();
        _ = io;

        c.igStyleColorsDark(null);

        _ = c.ImGui_ImplGlfw_InitForOpenGL(@ptrCast(*c.GLFWwindow, self.data.glfw_window.handle), true);
        _ = c.ImGui_ImplOpenGL3_Init("#version 130");


        try self.initGameRenderbuffer();

        // debug
        try self.initFullscreenQuadVAO();

        return self;
    }

    fn imguiGameRenderSizeConstraintCallback(data_ptr : [*c]c.ImGuiSizeCallbackData) callconv(.C) void
    {
        if (data_ptr) |data|
        {
            var self : *Context = @ptrCast(*Context, @alignCast(@alignOf(Context), data.*.UserData));
            
            var scale_x : u32 = @floatToInt(u32, std.math.round(data.*.DesiredSize.x / @intToFloat(f32, self.data.config.game_width)));
            var scale_y : u32 = @floatToInt(u32, std.math.round(data.*.DesiredSize.y / @intToFloat(f32, self.data.config.game_height)));

            var min = @minimum(scale_x, scale_y);

            self.data.current_zoom = @intCast(u8, min);

            data.*.DesiredSize = .{.x = @intToFloat(f32, min * self.data.config.game_width), .y = @intToFloat(f32, min * self.data.config.game_height)};
        }
    }

    pub fn run(self: *Context, callback : fn(ctxt : Context) anyerror!void) !void
    {
        std.log.info("{d: >7.4} starting main loop ...", .{glfw.getTime()});
        var show_demo_window : bool = true;
        while (!self.data.glfw_window.shouldClose()) {

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

            gl.viewport(0, 0, @intCast(c_int, self.data.config.game_width), @intCast(c_int, self.data.config.game_height));

            gl.bindFramebuffer(gl.FRAMEBUFFER, self.data.game_buffer);
            try callback(self.*);
            gl.bindFramebuffer(gl.FRAMEBUFFER, 0);

            c.igSetNextWindowSizeConstraints(.{.x = 0, .y = 0}, .{.x = std.math.f32_max, .y = std.math.f32_max}, imguiGameRenderSizeConstraintCallback, self);

            c.igPushStyleVar_Vec2(c.ImGuiStyleVar_WindowPadding, .{.x = 0, .y = 0});
            _ = c.igBegin("Scene Window", null, c.ImGuiWindowFlags_NoScrollbar);
            c.igImage(@intToPtr(*anyopaque, self.data.game_texture), .{.x = @intToFloat(f32, self.data.config.game_width * @intCast(u32, self.data.current_zoom)), .y = @intToFloat(f32, self.data.config.game_height * @intCast(u32, self.data.current_zoom))}, .{.x = 0, .y = 1}, .{.x = 1, .y = 0}, .{.x = 1.0, .y = 1.0, .z = 1.0, .w = 1.0}, .{.x = 1.0, .y = 1.0, .z = 1.0, .w = 0.0});

            c.igEnd();
            c.igPopStyleVar(1);

            gl.viewport(0,0, @intCast(gl.GLint, self.data.config.window_width), @intCast(gl.GLint, self.data.config.window_height));

            gl.useProgram(self.data.screen_shader);
            gl.bindVertexArray(vertex_array_object);
            gl.bindTexture(gl.TEXTURE_2D, self.data.game_texture);
            gl.drawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, null);

            gl.bindTexture(gl.TEXTURE_2D, 0);

            c.igRender();
            c.ImGui_ImplOpenGL3_RenderDrawData(c.igGetDrawData());

            try glfw.Window.swapBuffers(self.data.glfw_window);
        }
    }

    pub fn deinit(self : *Context) void
    {
        self.data.glfw_window.destroy();
        glfw.terminate();
        self.allocator.destroy(self.data);
    }
};


