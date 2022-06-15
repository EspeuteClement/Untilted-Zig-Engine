const std = @import("std");
const gl = @import("gl");
const window = @import("../window.zig");
const glhelp = @import("../glhelp.zig");
const aseprite = @import("../aseprite.zig");
const texture = @import("../texture.zig");
const sprite = @import("../sprite.zig");
const shader = @import("../shader.zig");

var program: gl.GLuint = undefined;

var vertex_array_object: gl.GLuint = undefined;
var vertex_buffer_object: gl.GLuint = undefined;
var element_buffer_object: gl.GLuint = undefined;
var instance_vertex_buffer_object: gl.GLuint = undefined;
var camera_uniform: gl.GLint = undefined;
var texture_handle: texture.TextureHandle = undefined;
var sprite_handle: sprite.Spr = .@"leneth";


const ShaderUniform = struct {
    uCamera: shader.Camera = undefined,
};

var batch: sprite.Batch = undefined;

var game_shader: shader.Shader(ShaderUniform) = undefined;

pub fn init(ctxt: window.Context) !void {
    _ = ctxt;

    batch = try sprite.Batch.init(ctxt.allocator);
    errdefer batch.deinit();
    batch.texture_handle = try texture.loadTexture("asset-build/testAtlas.qoi", .{});

    game_shader = @TypeOf(game_shader).init(try glhelp.buildProgram(@embedFile("game.vert"), @embedFile("game.frag")));
}

pub fn deinit(ctxt: window.Context) void {
    _ = ctxt;
    batch.deinit();
    game_shader.deinit();
}

var time: usize = 0;

pub fn run(ctxt: window.Context) !void {
    _ = ctxt;

    time += 1;

    const w = @intToFloat(f32, ctxt.data.config.game_width);
    const h = @intToFloat(f32, ctxt.data.config.game_height);
    const fTime = @intToFloat(f32, time);

    //try batch.drawSimple(.@"leneth", @divTrunc(time, 10) % 4, 150.0, 150.0);

    var i: usize = 0;
    while (i < 100) {
        const fi = @intToFloat(f32, i);
        try batch.drawSimple(.{.index = 1}, 200.0 + 100 * std.math.sin(fTime / 100.0 + fi) + std.math.sin(fTime / 500 + fi * 743.0) * 300.0, 200.0 + 100 * std.math.cos(fTime / 100.0 + fi) + std.math.cos(fTime / 500 + fi * 114.0) * 200.0);
        i += 1;
    }

    gl.clearColor(0, 1, 1, 1);
    gl.clear(gl.COLOR_BUFFER_BIT);

    game_shader.bind(.{ .uCamera = shader.makeCamera(0.0 + @cos(fTime/60.0) * 100, 0.0 + @sin(fTime/60.0) * 100, w, h) });

    try batch.render();
}
