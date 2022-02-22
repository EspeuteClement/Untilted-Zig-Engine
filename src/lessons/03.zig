// Hello rectangle

const std = @import("std");
const gl = @import("gl");
const glhelp = @import("../glhelp.zig");
const window = @import("../window.zig");

const vert_source : [:0]const u8 = @embedFile("03.vert");
const frag_source : [:0]const u8 = @embedFile("03.frag");

const vertices : []const f32 = &[_]f32 {
    0.5, 0.5, 0.0,
    0.5, -0.5, 0.0,
    -0.5, -0.5, 0.0,
    -0.5, 0.5, 0.0,
};

const indices : []const gl.GLuint = &[_]gl.GLuint {
    0,1,3,
    1,2,3,
};

var vertex_buffer_object : gl.GLuint = undefined;
var vertex_array_object : gl.GLuint = undefined;
var element_buffer_object : gl.GLuint = undefined;

var shader_program : gl.GLuint = undefined;

pub fn init(ctxt : window.Context) !void
{
    _ = ctxt;

    gl.genVertexArrays(1, &vertex_array_object);

    gl.genBuffers(1, &vertex_buffer_object);
    gl.genBuffers(1, &element_buffer_object);


    gl.bindVertexArray(vertex_array_object);

    gl.bindBuffer(gl.ARRAY_BUFFER, vertex_buffer_object);
    gl.bufferData(gl.ARRAY_BUFFER, vertices.len * @sizeOf(f32), vertices.ptr, gl.STATIC_DRAW);

    gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, element_buffer_object);
    gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, indices.len * @sizeOf(gl.GLuint), indices.ptr, gl.STATIC_DRAW);
    
    shader_program = try glhelp.buildProgram(vert_source, frag_source);

    gl.vertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 3 * @sizeOf(f32), null);
    gl.enableVertexAttribArray(0);

    gl.bindVertexArray(0);
}

pub fn run(ctxt : window.Context) !void
{
    _ = ctxt;

    gl.clearColor(0.2, 0.3, 0.3, 1.0);
    gl.clear(gl.COLOR_BUFFER_BIT);

    gl.useProgram(shader_program);
    gl.bindVertexArray(vertex_array_object);

    gl.drawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, null);
}