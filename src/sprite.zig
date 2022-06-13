const std = @import("std");
const Allocator = std.mem.Allocator;

const texture = @import("texture.zig");

const aseprite = @import("aseprite.zig");
const gl = @import("gl");
const meta = @import("meta.zig");

pub const Spr = enum(usize) {
    @"leneth",
};

fn sprPath(spr: Spr) []const u8 {
    return @typeInfo(Spr).Enum.fields[@enumToInt(spr)].name;
}

const spr_paths = meta.enumNames(Spr);

pub const FrameInfo = struct {
    x_offset: i16 = 0,
    y_offset: i16 = 0,
    u0: i16 = 0,
    v0: i16 = 0,
    u1: i16 = 0,
    v1: i16 = 0,
    texture_id : u16 = 0,
};

const SpriteInfo = struct {
    frames: []FrameInfo = undefined,

    fn init(allocator: Allocator, num_frames: usize) !Self {
        var info: SpriteInfo = undefined;
        info.frames = try allocator.alloc(FrameInfo, num_frames);
        return info;
    }

    fn deinit(self: *Self, allocator: Allocator) void {
        allocator.free(self.frames);
        self.* = undefined;
    }

    const Self = @This();
};

var sprites: []?SpriteInfo = undefined;

var local_alloc: Allocator = undefined;

pub fn init(allocator: Allocator) !void {
    local_alloc = allocator;
    sprites = try allocator.alloc(?SpriteInfo, @typeInfo(Spr).Enum.fields.len);
    std.mem.set(?SpriteInfo, sprites, null);

    try initQuad();
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

pub fn loadSprite(sprite_handle: Spr) !void {
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

    for (info.frames) |*frame, i| {
        const json_frame_data = &json_data.data.frames[i];
        frame.x_offset = json_frame_data.spriteSourceSize.x;
        frame.y_offset = json_frame_data.spriteSourceSize.y;
        frame.u0 = json_frame_data.frame.x;
        frame.v0 = json_frame_data.frame.y;
        frame.u1 = frame.u0 + json_frame_data.frame.w;
        frame.v1 = frame.v0 + json_frame_data.frame.h;
    }
}

fn getOrLoad(sprite_handle: Spr) !*SpriteInfo {
    const info_index = @enumToInt(sprite_handle);

    if (sprites[info_index] == null) {
        try loadSprite(sprite_handle);
    }
    return &sprites[info_index].?;
}

pub fn getFrameInfo(sprite_handle: Spr, image_index: usize) !FrameInfo {
    var info = try getOrLoad(sprite_handle);
    return info.frames[image_index % info.frames.len];
}

pub fn deinit() void {
    for (sprites) |*spr| {
        if (spr.*) |*spr_not_null| {
            spr_not_null.deinit(local_alloc);
        }
    }
    local_alloc.free(sprites);

    deinitQuad();
}

test "regular load" {
    _ = spr_paths;
    try std.testing.expectEqualStrings(spr_paths[@enumToInt(Spr.@"leneth")], "leneth");

    try init(std.testing.allocator);
    defer deinit();

    try loadSprite(Spr.@"leneth");

    const i = @enumToInt(Spr.@"leneth");
    try std.testing.expectEqual(sprites[i].?.frames[0].x_offset, 39);
    try std.testing.expectEqual(sprites[i].?.frames[0].y_offset, 46);
    try std.testing.expectEqual(sprites[i].?.frames[0].u1, 49);
    try std.testing.expectEqual(sprites[i].?.frames[0].v1, 48 + 50);
}

test "get frame info" {
    try init(std.testing.allocator);
    defer deinit();

    var info = try getFrameInfo(Spr.@"leneth", 0);

    try std.testing.expectEqual(info.x_offset, 39);
    try std.testing.expectEqual(info.y_offset, 46);
    try std.testing.expectEqual(info.u1, 49);
    try std.testing.expectEqual(info.v1, 48 + 50);
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

    pub fn drawSimple(self: *Self, sprite: Spr, frame: usize, x: f32, y: f32) !void {
        const spr_info = try getFrameInfo(sprite, frame);

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

    pub fn drawQuad(self: *Self, quad_info: BufferInfo) !void {
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
                if (self.drawn_this_frame < self.last_gl_size) {
                    gl.bufferSubData(gl.ARRAY_BUFFER, 0, @intCast(isize, self.drawn_this_frame * @sizeOf(BufferInfo)), &self.buffer.items[0]);
                } else {
                    gl.bufferData(gl.ARRAY_BUFFER, @intCast(isize, self.drawn_this_frame * @sizeOf(BufferInfo)), &self.buffer.items[0], gl.DYNAMIC_DRAW);
                }
            }

            gl.bindVertexArray(self.vao);
            gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);

            texture.bindTexture(texture_handle_not_null);

            gl.drawElementsInstanced(gl.TRIANGLES, 6, gl.UNSIGNED_INT, null, @intCast(c_int, self.drawn_this_frame));
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
