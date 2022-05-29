const std = @import("std");
const Allocator = std.mem.Allocator;

const texture = @import("texture.zig");

const aseprite = @import("aseprite.zig");
const gl = @import("gl");

pub const Spr = enum(usize) {
    @"leneth",
};

const spr_paths = r: {
    var paths : [@typeInfo(Spr).Enum.fields.len][]const u8 = undefined;
    for (@typeInfo(Spr).Enum.fields) |field, i|
    {
        paths[i] = field.name;
    }
    break :r paths;
};

const SpriteInfo = struct {
    frames : []FrameInfo = undefined,

    const FrameInfo = struct {
        x_offset : isize = 0,
        y_offset : isize = 0,
        u0 : isize = 0,
        v0 : isize = 0,
        u1 : isize = 0,
        v1 : isize = 0,
    };

    fn init(allocator : Allocator, num_frames : usize) !Self
    {
        var info : SpriteInfo = undefined;
        info.frames = try allocator.alloc(SpriteInfo.FrameInfo, num_frames);
        return info;
    }

    fn deinit(self : *Self, allocator : Allocator) void
    {
        allocator.free(self.frames);
        self.* = undefined;
    }

    const Self = @This();
};

var sprites : []?SpriteInfo = undefined;

var local_alloc : Allocator = undefined;

pub fn init(allocator : Allocator) !void
{
    local_alloc = allocator;
    sprites = try allocator.alloc(?SpriteInfo, @typeInfo(Spr).Enum.fields.len);
    std.mem.set(?SpriteInfo, sprites, null);

    try initQuad();
}

var quad_vbo : gl.GLuint = undefined;
var quad_ebo : gl.GLuint = undefined;

pub fn initQuad() !void
{
    gl.genBuffers(1, &quad_vbo);
    gl.genBuffers(1, &quad_ebo);

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

    gl.bindBuffer(gl.ARRAY_BUFFER, quad_vbo);
    gl.bufferData(gl.ARRAY_BUFFER, @sizeOf(@TypeOf(vertices)), &vertices[0], gl.STATIC_DRAW);

    gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, quad_ebo);
    gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, @sizeOf(@TypeOf(indices)), &indices[0], gl.STATIC_DRAW);
}

pub fn deinitQuad() void
{
    gl.deleteBuffers(1, &quad_vbo);
    gl.deleteBuffers(1, &quad_ebo);
}

pub fn loadSprite(sprite_handle : Spr) !void
{
    const info_index = @enumToInt(sprite_handle);

    var json_path = try std.fmt.allocPrint(local_alloc, "data/{s}.json", .{spr_paths[info_index]});
    defer local_alloc.free(json_path);

    var png_path = try std.fmt.allocPrintZ(local_alloc, "data/{s}.png", .{spr_paths[info_index]});
    defer local_alloc.free(png_path);

    var json_data = try aseprite.getSpriteSheetDataFromFile(json_path, local_alloc);
    defer aseprite.freeSpriteSheetData(json_data);

    var info = try SpriteInfo.init(local_alloc, json_data.data.frames.len);
    errdefer local_alloc.free(info);

    sprites[info_index] = info;

    for (info.frames) |*frame, i|
    {
        const json_frame_data = &json_data.data.frames[i];
        frame.x_offset = -json_frame_data.spriteSourceSize.x;
        frame.y_offset = -json_frame_data.spriteSourceSize.y;
        frame.u0 = json_frame_data.frame.x;
        frame.v0 = json_frame_data.frame.y;
        frame.u1 = json_frame_data.frame.w;
        frame.v1 = json_frame_data.frame.h;
    }
}

fn getOrLoad(sprite_handle : Spr) !*SpriteInfo
{
    const info_index = @enumToInt(sprite_handle);

    if (sprites[info_index] == null)
    {
        try loadSprite(sprite_handle);
    }
    return &sprites[info_index].?;
}

pub fn getFrameInfo(sprite_handle : Spr, image_index : usize) !SpriteInfo.FrameInfo
{
    var info = try getOrLoad(sprite_handle);
    return info.frames[image_index % info.frames.len];
}

pub fn deinit() void
{
    for (sprites) |*spr|
    {
        if (spr.*) |*spr_not_null|
        {
            spr_not_null.deinit(local_alloc);
        }
    }
    local_alloc.free(sprites);

    deinitQuad();
}

test "regular load" {
    _ = spr_paths;
    try std.testing.expectEqualStrings(spr_paths[@enumToInt(Spr.@"leneth")],"leneth");

    try init(std.testing.allocator);
    defer deinit();

    try loadSprite(Spr.@"leneth");

    const i = @enumToInt(Spr.@"leneth");
    try std.testing.expectEqual(sprites[i].?.frames[0].x_offset, -39);
    try std.testing.expectEqual(sprites[i].?.frames[0].y_offset, -46);
    try std.testing.expectEqual(sprites[i].?.frames[0].u1, 49);
    try std.testing.expectEqual(sprites[i].?.frames[0].v1, 50);
}

test "get frame info" {
    try init(std.testing.allocator);
    defer deinit();

    var info = try getFrameInfo(Spr.@"leneth", 0);

    try std.testing.expectEqual(info.x_offset, -39);
    try std.testing.expectEqual(info.y_offset, -46);
    try std.testing.expectEqual(info.u1, 49);
    try std.testing.expectEqual(info.v1, 50);
}

const Batch = struct {
    buffer : std.ArrayList(BufferInfo) = undefined,
    
    // Number of actual element drawn this frame
    drawn_this_frame : usize = 0,

    // Size of the allocated driver memory
    last_gl_size : usize = undefined,

    vao : gl.GLuint = undefined,
    vbo : gl.GLuint = undefined,

    texture_handle : texture.TextureHandle = undefined,

    pub fn init(allocator : Allocator) !Batch
    {
        var self = Batch{};

        self.last_gl_size = 0;
        self.buffer = @TypeOf(self.buffer).initCapacity(allocator, 4096);

        gl.genVertexArrays(1, &self.vao);
        gl.bindVertexArray(self.vao);

        gl.bindBuffer(gl.ARRAY_BUFFER, quad_vbo);
        gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, quad_ebo);

        gl.enableVertexAttribArray(0);
        gl.vertexAttribPointer(0, 2, gl.FLOAT, gl.FALSE, 2 * @sizeOf(f32), @intToPtr(?*const anyopaque, 0));

        gl.genBuffers(1, &self.vbo);

        gl.bindBuffer(gl.ARRAY_BUFFER, self.vbo);
        gl.bufferData(gl.ARRAY_BUFFER, @sizeOf(BufferInfo) * self.size, null, gl.STREAM_DRAW);

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

        // TODO(ces) : Proper texture managment
        self.texture_handle = texture.loadTexture("data/leneth.png", .{});

        return self;
    }

    pub fn render(self : *Self) !void
    {
        gl.bindBuffer(gl.ARRAY_BUFFER, self.vbo);
        if (self.drawn_this_frame < self.last_gl_size)
        {
            gl.bufferSubData(gl.ARRAY_BUFFER, 0, self.drawn_this_frame * @sizeOf(BufferInfo), &self.buffer.items[0]);
        }
        else
        {
            gl.bufferData(gl.ARRAY_BUFFER, self.drawn_this_frame  * @sizeOf(BufferInfo),&self.buffer.items[0], gl.DYNAMIC_DRAW);
        }

        gl.bindVertexArray(self.vao);
        gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);

        texture.bindTexture(self.texture_handle);

        gl.drawElementsInstanced(gl.TRIANGLES, 6, gl.UNSIGNED_INT, null, self.drawn_this_frame);

        self.drawn_this_frame = 0;
    }

    pub fn deinit(self : *Self) !void
    {
        gl.deleteVertexArrays(1, &self.vao);
    }

    const BufferInfo = packed struct {
        x : f32 = 0,
        y : f32 = 0,
        w : i16 = 0,
        h : i16 = 0,
        u0 : i16 = 0,
        v0 : i16 = 0,
        u1 : i16 = 0,
        v1 : i16 = 0,
    };

    const Self = Batch;
};