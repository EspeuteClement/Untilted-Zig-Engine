// Helpers functions for opengl
const std = @import("std");
const gl = @import("gl");

var err_buffer : [512]gl.GLchar = [_] gl.GLchar {0} ** 512;
const err_buffer_ptr : [*c]gl.GLchar = &err_buffer;

pub const ShaderKind = enum {
    vertex,
    fragment,
};

pub const BuildShaderError = error {
    ShaderCompilationFail,
};

pub const BuildProgramError = BuildShaderError || error {
    ProgramLinkError,
};

pub fn buildShader(source :  [:0]const u8, comptime kind : ShaderKind) BuildShaderError!gl.GLuint
{
    const shaderType : gl.GLenum = switch(kind) {
        .vertex => gl.VERTEX_SHADER,
        .fragment => gl.FRAGMENT_SHADER,
    };

    var vertex_shader : gl.GLuint = gl.createShader(shaderType);
    errdefer gl.deleteShader(vertex_shader);
    gl.shaderSource(vertex_shader, 1, &source.ptr, null);
    gl.compileShader(vertex_shader);

    var success : gl.GLint = undefined;
    gl.getShaderiv(vertex_shader, gl.COMPILE_STATUS, &success);
    if (success == 0)
    {
        gl.getShaderInfoLog(vertex_shader, err_buffer.len * @sizeOf(gl.GLchar), null, err_buffer_ptr);
        std.log.err("Shader compilation failed : {s}", .{err_buffer_ptr});
        return BuildShaderError.ShaderCompilationFail;
    }
    return vertex_shader;
}

pub fn buildProgram(vert_source : [:0]const u8, frag_source : [:0]const u8) BuildProgramError!gl.GLuint
{
    var vertex_shader : gl.GLuint = try buildShader(vert_source, .vertex);
    defer gl.deleteShader(vertex_shader);

    var fragment_shader : gl.GLuint = try buildShader(frag_source, .fragment);
    defer gl.deleteShader(fragment_shader);

    var program : gl.GLuint = gl.createProgram();
    errdefer gl.deleteProgram(program);

    gl.attachShader(program, vertex_shader);
    gl.attachShader(program, fragment_shader);
    gl.linkProgram(program);

    var success : gl.GLint = undefined;
    gl.getProgramiv(program, gl.LINK_STATUS, &success);
    if (success == 0)
    {
        gl.getProgramInfoLog(vertex_shader, err_buffer.len * @sizeOf(gl.GLchar), null, err_buffer_ptr);
        std.log.err("Program link failed : {s}", .{err_buffer_ptr});
        return BuildProgramError.ProgramLinkError;
    }

    return program;
}