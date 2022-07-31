const std = @import("std");
const Allocator = std.mem.Allocator;

const texture = @import("texture.zig");

const aseprite = @import("aseprite.zig");
const gl = @import("gl");
const meta = @import("meta.zig");
const library = @import("library.zig");
const serialize = @import("serialize.zig");

const profile = @import("profile.zig");

pub const SpriteInfo = struct {
    x_offset: i16 = 0,
    y_offset: i16 = 0,
    u0: i16 = 0,
    v0: i16 = 0,
    u1: i16 = 0,
    v1: i16 = 0,
    texture_id : u16 = 0,
};

const SpriteLibrary = library.Library(SpriteInfo);

// Api interface from the outside world
pub const Sprite = SpriteLibrary.Key;

pub var spriteLibrary : SpriteLibrary = undefined;


var local_alloc: Allocator = undefined;

pub fn init(allocator: Allocator) !void {
    local_alloc = allocator;

    try initSprites();
    errdefer deinitSprites();

    try initQuad();
    errdefer deinitQuad();
}

fn initSprites() !void {
    spriteLibrary = SpriteLibrary.init(local_alloc);
    errdefer spriteLibrary.deinit();

    var file = try std.fs.cwd().openFile("asset-build/testData.bin", .{});
    defer file.close();

    var reader = file.reader();

    while(true)
    {
        var data = serialize.deserialise(SpriteInfo, reader) catch |err| switch(err)
        {
            error.EndOfStream => break,
            else => return err,
        };

        _ = try spriteLibrary.add(data);
    }
}

fn deinitSprites() void {
    spriteLibrary.deinit();
}

var quad_vbo: gl.GLuint = undefined;
var quad_ebo: gl.GLuint = undefined;

pub fn initQuad() !void {
    gl.genBuffers(1, &quad_vbo);
    gl.genBuffers(1, &quad_ebo);

    const vertices = [_]f32{
        1, 1,
        1, 0,
        0, 0,
        0, 1,
    };

    const indices = [_]gl.GLuint{
        0, 1, 3,
        1, 2, 3,
    };

    gl.bindBuffer(gl.ARRAY_BUFFER, quad_vbo);
    gl.bufferData(gl.ARRAY_BUFFER, @sizeOf(@TypeOf(vertices)), &vertices[0], gl.STATIC_DRAW);

    gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, quad_ebo);
    gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, @sizeOf(@TypeOf(indices)), &indices[0], gl.STATIC_DRAW);
}

pub fn deinitQuad() void {
    gl.deleteBuffers(1, &quad_vbo);
    gl.deleteBuffers(1, &quad_ebo);
}

pub fn deinit() void {
    deinitSprites();
    deinitQuad();
}

pub const Batch = struct {
    buffer: std.ArrayList(BufferInfo) = undefined,

    // Number of actual element drawn this frame
    drawn_this_frame: usize = 0,

    // Size of the allocated driver memory
    last_gl_size: usize = undefined,

    vao: gl.GLuint = undefined,
    vbo: gl.GLuint = undefined,

    texture_handle: ?texture.TextureHandle = null,

    pub fn init(allocator: Allocator) !Batch {
        var self = Batch{};

        self.last_gl_size = 0;
        self.buffer = try @TypeOf(self.buffer).initCapacity(allocator, 4096);

        gl.genVertexArrays(1, &self.vao);
        gl.bindVertexArray(self.vao);

        gl.bindBuffer(gl.ARRAY_BUFFER, quad_vbo);
        gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, quad_ebo);

        gl.enableVertexAttribArray(0);
        gl.vertexAttribPointer(0, 2, gl.FLOAT, gl.FALSE, 2 * @sizeOf(f32), @intToPtr(?*const anyopaque, 0));

        gl.genBuffers(1, &self.vbo);

        gl.bindBuffer(gl.ARRAY_BUFFER, self.vbo);

        // Offset position
        gl.enableVertexAttribArray(1);
        gl.vertexAttribPointer(1, 2, gl.FLOAT, gl.FALSE, @sizeOf(BufferInfo), @intToPtr(?*const anyopaque, @offsetOf(BufferInfo, "x")));
        gl.vertexAttribDivisor(1, 1);

        // Size
        gl.enableVertexAttribArray(2);
        gl.vertexAttribPointer(2, 2, gl.SHORT, gl.FALSE, @sizeOf(BufferInfo), @intToPtr(?*const anyopaque, @offsetOf(BufferInfo, "w")));
        gl.vertexAttribDivisor(2, 1);

        // UV0
        gl.enableVertexAttribArray(3);
        gl.vertexAttribPointer(3, 2, gl.SHORT, gl.FALSE, @sizeOf(BufferInfo), @intToPtr(?*const anyopaque, @offsetOf(BufferInfo, "u0")));
        gl.vertexAttribDivisor(3, 1);

        // UV1
        gl.enableVertexAttribArray(4);
        gl.vertexAttribPointer(4, 2, gl.SHORT, gl.FALSE, @sizeOf(BufferInfo), @intToPtr(?*const anyopaque, @offsetOf(BufferInfo, "u1")));
        gl.vertexAttribDivisor(4, 1);

        gl.bindVertexArray(0);
        gl.bindBuffer(gl.ARRAY_BUFFER, 0);
        gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, 0);

        return self;
    }

    pub inline fn drawSimple(self: *Self, sprite: Sprite, x: f32, y: f32) !void {
        const spr_info = try spriteLibrary.get(sprite);

        try self.drawSpriteInfo(spr_info, x, y);
    }

    pub inline fn drawSpriteInfo(self: *Self, spr_info : SpriteInfo, x: f32, y: f32) !void {
        try self.drawQuad(BufferInfo{
            .x = x + @intToFloat(f32, spr_info.x_offset),
            .y = y + @intToFloat(f32, spr_info.y_offset),
            .w = spr_info.u1 - spr_info.u0,
            .h = spr_info.v1 - spr_info.v0,
            .u0 = spr_info.u0,
            .v0 = spr_info.v0,
            .u1 = spr_info.u1,
            .v1 = spr_info.v1,
        });
    }

    pub inline fn drawQuad(self: *Self, quad_info: BufferInfo) !void {
        try self.buffer.ensureTotalCapacity(self.drawn_this_frame + 1);
        self.buffer.expandToCapacity();

        self.buffer.items[self.drawn_this_frame] = quad_info;

        self.drawn_this_frame += 1;
    }

    pub fn render(self: *Self) !void {
        try self.renderNoClear();
        self.drawn_this_frame = 0;
    }

    pub fn renderNoClear(self: *Self) !void {
        if (self.texture_handle) |texture_handle_not_null| {
            gl.bindBuffer(gl.ARRAY_BUFFER, self.vbo);
            if (self.buffer.items.len > 0) {
                var prof = profile.begin(@src(), "bufferData"); defer prof.end();

                if (self.drawn_this_frame <= self.last_gl_size) {
                    gl.bufferSubData(gl.ARRAY_BUFFER, 0, @intCast(isize, self.drawn_this_frame * @sizeOf(BufferInfo)), &self.buffer.items[0]);
                } else {
                    gl.bufferData(gl.ARRAY_BUFFER, @intCast(isize, self.drawn_this_frame * @sizeOf(BufferInfo)), &self.buffer.items[0], gl.DYNAMIC_DRAW);
                    self.last_gl_size = self.drawn_this_frame;
                }

            }

            gl.bindVertexArray(self.vao);
            gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);

            texture.bindTexture(texture_handle_not_null);
            
            {
                var prof = profile.begin(@src(), "drawElementsInstanced"); defer prof.end();
                gl.drawElementsInstanced(gl.TRIANGLES, 6, gl.UNSIGNED_INT, null, @intCast(c_int, self.drawn_this_frame));
            }   

        } else {
            return error.NoTextureBound;
        }
    }

    pub fn deinit(self: *Self) void {
        gl.deleteVertexArrays(1, &self.vao);
        self.buffer.deinit();
        self.* = undefined;
    }

    pub const BufferInfo = packed struct {
        x: f32 = 0,
        y: f32 = 0,
        w: i16 = 0,
        h: i16 = 0,
        u0: i16 = 0,
        v0: i16 = 0,
        u1: i16 = 0,
        v1: i16 = 0,
    };

    const Self = Batch;
};
