const std = @import("std");
const gl = @import("gl");
const window = @import("../window.zig");
const glhelp = @import("../glhelp.zig");
const stb = @import("../stbi.zig");

var program : gl.GLuint = undefined;

var vertex_array_object : gl.GLuint = undefined;
var vertex_buffer_object : gl.GLuint = undefined;
var element_buffer_object : gl.GLuint = undefined;
var instance_vertex_buffer_object : gl.GLuint = undefined;
var camera_uniform : gl.GLint = undefined;
var texture_handle : gl.GLuint = undefined;

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

pub fn init(ctxt : window.Context) !void
{
    _ = ctxt;

    program = try glhelp.buildProgram(@embedFile("05.vert"), @embedFile("05.frag"));

    gl.genVertexArrays(1, &vertex_array_object);
    gl.bindVertexArray(vertex_array_object);

    gl.genBuffers(1, &vertex_buffer_object);
    gl.genBuffers(1, &instance_vertex_buffer_object);
    gl.genBuffers(1, &element_buffer_object);

    const vertices = [_]f32 {
        1, 1,
        1, 0,
        0, 0,
        0, 1,
    };

    const indices = [_]gl.GLuint {
        0,1,3,
        1,2,3,
    };

    var i : usize = 0;
    for (instance_offsets) |*instance|
    {
        
        var x : f32 = @intToFloat(f32, @intCast(isize, i % 10)) / 10.0;
        var y : f32 = @intToFloat(f32, @intCast(isize, i / 10)) / 10.0;
        instance.x = x * @intToFloat(f32, ctxt.data.config.game_width);
        instance.y = y * @intToFloat(f32, ctxt.data.config.game_height);
        instance.w = 64;
        instance.h = 32;
        instance.u0 = @floatToInt(i16, x * @as(f32,std.math.maxInt(i16)));
        instance.v0 = @floatToInt(i16, y * @as(f32, std.math.maxInt(i16)));
        instance.u1 = @floatToInt(i16, (x+0.5) * @as(f32,std.math.maxInt(i16)));
        instance.v1 = @floatToInt(i16, (y+0.5) * @as(f32, std.math.maxInt(i16)));
    }

    gl.bindBuffer(gl.ARRAY_BUFFER, vertex_buffer_object);
    gl.bufferData(gl.ARRAY_BUFFER, @sizeOf(@TypeOf(vertices)), &vertices[0], gl.STATIC_DRAW);

    gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, element_buffer_object);
    gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, @sizeOf(@TypeOf(indices)), &indices[0], gl.STATIC_DRAW);

    gl.enableVertexAttribArray(0);
    gl.vertexAttribPointer(0, 2, gl.FLOAT, gl.FALSE, 2 * @sizeOf(f32), @intToPtr(?*const anyopaque, 0));
    
    gl.bindBuffer(gl.ARRAY_BUFFER, instance_vertex_buffer_object);
    gl.bufferData(gl.ARRAY_BUFFER, @sizeOf(@TypeOf(instance_offsets)), &instance_offsets, gl.DYNAMIC_DRAW);

    // Offset position
    gl.enableVertexAttribArray(1);
    gl.vertexAttribPointer(1, 2, gl.FLOAT, gl.FALSE, @sizeOf(SpriteInfo), @intToPtr(?*const anyopaque, @offsetOf(SpriteInfo, "x")));
    gl.vertexAttribDivisor(1, 1);

    // Size
    gl.enableVertexAttribArray(2);
    gl.vertexAttribPointer(2, 2, gl.SHORT, gl.FALSE, @sizeOf(SpriteInfo), @intToPtr(?*const anyopaque, @offsetOf(SpriteInfo, "w")));
    gl.vertexAttribDivisor(2, 1);

    // UV0
    gl.enableVertexAttribArray(3);
    gl.vertexAttribPointer(3, 2, gl.SHORT, gl.TRUE, @sizeOf(SpriteInfo), @intToPtr(?*const anyopaque, @offsetOf(SpriteInfo, "u0")));
    gl.vertexAttribDivisor(3, 1);

    // UV1
    gl.enableVertexAttribArray(4);
    gl.vertexAttribPointer(4, 2, gl.SHORT, gl.TRUE, @sizeOf(SpriteInfo), @intToPtr(?*const anyopaque, @offsetOf(SpriteInfo, "u1")));
    gl.vertexAttribDivisor(4, 1);

    camera_uniform = gl.getUniformLocation(program, @as([*c]const gl.GLchar, "uCamera"));
    if (camera_uniform < 0)
        @panic("Couln't find uniform");

    {
        var x : c_int = undefined;
        var y : c_int = undefined;
        var n : c_int = undefined;

        var data : [*c]u8 = stb.stbi_load("data/checker.png", &x, &y, &n, 4);
        if (data == null)
            return error.StbiLoadFail;
        defer stb.stbi_image_free(data);

        gl.genTextures(1, &texture_handle);
        gl.bindTexture(gl.TEXTURE_2D, texture_handle);

        gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, x, y, 0, gl.RGBA, gl.UNSIGNED_BYTE, data);
        gl.generateMipmap(gl.TEXTURE_2D);

        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST_MIPMAP_NEAREST);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST_MIPMAP_NEAREST);
    }
}

var time : usize = 0;

pub fn run(ctxt : window.Context) !void
{
    _ = ctxt;

    const w = @intToFloat(f32, ctxt.data.config.game_width);
    const h = @intToFloat(f32, ctxt.data.config.game_height);
    const mat = [_]f32 {
         -2.0 / w, 0.0, 0.0, 1,
         0.0,-2.0 / h, 0.0, 1,
         0.0, 0.0, 1.0, 0,
         0.0, 0.0, 0.0, 1.0
    };

    time += 1;

    instance_offsets[0].x = @floor(@intToFloat(f32, (time * 4) % 640)) ;
    instance_offsets[0].y = 100;

    std.log.info("{d}", .{instance_offsets[0]});

    gl.clearColor(1, 0, 1, 1);
    gl.clear(gl.COLOR_BUFFER_BIT);

    gl.bindBuffer(gl.ARRAY_BUFFER, instance_vertex_buffer_object);
    gl.bufferSubData(gl.ARRAY_BUFFER, 0, @sizeOf(@TypeOf(instance_offsets)), &instance_offsets);

    gl.useProgram(program);
    gl.uniformMatrix4fv(camera_uniform, 1, gl.TRUE, &mat[0]);
    gl.bindVertexArray(vertex_array_object);
    gl.bindTexture(gl.TEXTURE_2D, texture_handle);
    gl.drawElementsInstanced(gl.TRIANGLES, 6, gl.UNSIGNED_INT, null, 1);
}