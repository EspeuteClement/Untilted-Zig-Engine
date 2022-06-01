const std = @import("std");
const gl = @import("gl");

const glhelp = @import("glhelp.zig");

pub const Camera = struct {
    matrix : [16]f32,
};

pub fn makeCamera(x: f32, y:f32, w: f32, h: f32) Camera {
    const sx = -2.0/ w;
    const tx = 1 + std.math.floor(x) / w * 2.0;
    const sy = -2.0 / h;
    const ty = 1 + std.math.floor(y) / h * 2.0;
    
    return Camera{
        .matrix = [16]f32 {
            sx ,0.0,0.0,tx,
            0.0,sy ,0.0,ty,
            0.0,0.0,1.0,0.0,
            0.0,0.0,0.0,1.0
            },
    };
}

pub fn bindCamera(camera : Camera) void {
    _ = camera;
}


pub fn Shader(comptime uniform_struct : type) type {
    return struct {
        shader_handle : gl.GLuint,

        uniform_handler : Handler,

        pub fn init(shader_id : gl.GLuint) Self
        {
            var self = Self{
                .shader_handle = shader_id,
                .uniform_handler = Handler.init(),
            };

            self.uniform_handler.initUniforms(self);

            return self;
        }

        pub fn bind(self : *Self, uniforms : T) void
        {
            gl.useProgram(self.shader_handle);
            self.uniform_handler.bindUniforms(uniforms);
        }

        const Self = @This();
        const T = uniform_struct;
        const Handler = UniformHandler(T);
    };
}

const TestShaderParams = struct {
    uCamera : Camera = undefined,
};

fn UniformHandler(comptime T : type) type {
    const info = @typeInfo(T);
    if (info != .Struct) @compileError("Type " ++ @typeName(info) ++ " is not a struct");

    return struct {
        uniforms_handles : [info.Struct.fields.len]gl.GLint,

        fn init() Self
        {
            return Self{.uniforms_handles = undefined};
        }

        fn initUniforms(self : *Self, shader : anytype) void
        {
            inline for (info.Struct.fields) |field, i|
            {
                self.uniforms_handles[i] = gl.getUniformLocation(shader.shader_handle, @as([*c]const gl.GLchar, field.name ++ ""));
                if (self.uniforms_handles[i] < 0)
                    std.log.err("Couldn't find uniform named {s}", .{field.name});
            }
        }

        fn bindUniforms(self : *Self, parameters : T) void
        {
            inline for (info.Struct.fields) |field, i|
            {
                switch(field.field_type)
                {
                    Camera => gl.uniformMatrix4fv(self.uniforms_handles[i], 1, gl.TRUE, &@field(parameters, field.name).matrix),
                    else => @compileError("Type " ++ @typeName(field.field_type) ++ " not currently supported as uniform parameter"),
                }
            }
        }

        const Self = @This();
        const ParamType = T;
    };
}

test "Test Shaders" {
    const window = @import("window.zig");
    var context = try window.Context.init(std.testing.allocator);
    defer context.deinit();


    const S = Shader(TestShaderParams);
    var s = S.init(try glhelp.buildProgram(@embedFile("lessons/05.vert"), @embedFile("lessons/05.frag")));

    s.bind(TestShaderParams{.uCamera = makeCamera(0, 0, 640, 480)});
}