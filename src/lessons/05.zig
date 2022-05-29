const std = @import("std");
const gl = @import("gl");
const window = @import("../window.zig");
const glhelp = @import("../glhelp.zig");
const stb = @import("../stbi.zig");
const aseprite = @import("../aseprite.zig");
const texture = @import("../texture.zig");
const sprite = @import("../sprite.zig");

var program : gl.GLuint = undefined;

var vertex_array_object : gl.GLuint = undefined;
var vertex_buffer_object : gl.GLuint = undefined;
var element_buffer_object : gl.GLuint = undefined;
var instance_vertex_buffer_object : gl.GLuint = undefined;
var camera_uniform : gl.GLint = undefined;
var texture_handle : texture.TextureHandle = undefined;
var sprite_handle : sprite.Spr = .@"leneth";

var instance_offsets : [100]SpriteInfo = undefined;

const SpriteInfo = packed struct {
    x : f32 = 0,
    y : f32 = 0,
    w : i16 = 0,
    h : i16 = 0,
    u0 : i16 = 0,
    v0 : i16 = 0,
    u1 : i16 = 0,
    v1 : i16 = 0,
};

var batch : sprite.Batch = undefined;

pub fn init(ctxt : window.Context) !void
{
    _ = ctxt;

    try sprite.init(ctxt.allocator);
    errdefer sprite.deinit();

    try texture.init(ctxt.allocator);

    batch = try sprite.Batch.init(ctxt.allocator);

    program = try glhelp.buildProgram(@embedFile("05.vert"), @embedFile("05.frag"));

    camera_uniform = gl.getUniformLocation(program, @as([*c]const gl.GLchar, "uCamera"));
    if (camera_uniform < 0)
        @panic("Couln't find uniform");
}

var time : usize = 0;

pub fn makeCamera(x: f32, y:f32, w: f32, h: f32) [16]f32 {
    const sx = -2.0/ w;
    const tx = 1 + std.math.floor(x) / w * 2.0;
    const sy = -2.0 / h;
    const ty = 1 + std.math.floor(y) / h * 2.0;
    
    return [16]f32 {
        sx ,0.0,0.0,tx,
        0.0,sy ,0.0,ty,
        0.0,0.0,1.0,0.0,
        0.0,0.0,0.0,1.0
    };
}

pub fn run(ctxt : window.Context) !void
{
    _ = ctxt;

    time += 1;

    const w = @intToFloat(f32, ctxt.data.config.game_width);
    const h = @intToFloat(f32, ctxt.data.config.game_height);
    const fTime = @intToFloat(f32,time);
    const mat = makeCamera(0.0, 0.0, w, h);

    try batch.drawSimple(.@"leneth", @divTrunc(time, 10) % 4, 150.0, 150.0);

    var i :usize = 0;
    while (i < 10_000) 
    {
        const fi = @intToFloat(f32, i);
        try batch.drawSimple(.@"leneth", @divTrunc(time+i, 10) % 4, 
            200.0 + 100 * std.math.sin(fTime / 100.0 + fi) + std.math.sin(fTime / 500 + fi*743.0) * 300.0, 
            200.0 + 100 * std.math.cos(fTime / 100.0 + fi) + std.math.cos(fTime / 500 + fi*114.0) * 200.0)
            ;
        i += 1;
    }

    //std.log.info("{d}", .{instance_offsets[0]});
    gl.clearColor(0, 1, 1, 1);
    gl.clear(gl.COLOR_BUFFER_BIT);

    gl.useProgram(program);

    gl.uniformMatrix4fv(camera_uniform, 1, gl.TRUE, &mat[0]);

    try batch.render();
}