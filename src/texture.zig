const std = @import("std");
const gl = @import("gl");
const stb = @import("stbi.zig");


const Allocator = std.mem.Allocator;

const Library = @import("library.zig").Library;

const TextureInfo = struct {
    handle: gl.GLuint = undefined,
};

const FramebufferInfo = struct {
    handle: gl.GLuint = undefined,
    texture_handle : TextureHandle = undefined,
};

const TextureLibrary = Library(TextureInfo);
pub const TextureHandle = TextureLibrary.Key;

const FramebufferLibrary = Library(FramebufferInfo);
pub const FramebufferHandle = FramebufferLibrary.Key;

var textureLibrary : TextureLibrary = undefined;
var framebufferLibrary : FramebufferLibrary = undefined;

var is_init = false;

pub fn init(allocator : Allocator) !void
{
    defer is_init = true;

    if (is_init) @panic("Already init");
    textureLibrary = TextureLibrary.init(allocator);
    framebufferLibrary = FramebufferLibrary.init(allocator);
}

const LoadTextureParameters = struct {

};

pub fn loadTexture(path : [*c]const u8, params : LoadTextureParameters) !TextureHandle
{
    _ = params;
    var x : c_int = undefined;
    var y : c_int = undefined;
    var n : c_int = undefined;

    
    var data : [*c]u8 = stb.stbi_load(path, &x, &y, &n, 4);
    if (data == null)
        return error.StbiLoadFail;

    defer stb.stbi_image_free(data);

    return createTexture(.{
        .width = @intCast(u16, x),
        .height = @intCast(u16, y),
        .depth = .RGBA,
        .pixels = data,
        .min_filter = .NEAREST,
        .mag_filter = .NEAREST,
    });
}

const Filter = enum {
    NEAREST,
    BILINEAR,

    pub fn toGL(self : Filter) gl.GLint {
        return switch (self) {
            .NEAREST => gl.NEAREST,
            .BILINEAR => gl.LINEAR,
        };
    }
};

const Depth = enum {
    RGB,
    RGBA,

    pub fn toGL(self : Depth) gl.GLint {
        return switch (self) {
            .RGB => gl.RGB,
            .RGBA => gl.RGBA,
        };
    }
};

const CreateTextureParams = struct {
    width : u16,
    height : u16,
    min_filter : Filter = .NEAREST,
    mag_filter : Filter = .NEAREST,
    depth : Depth = .RGBA,
    mipmaps : bool = false,
    pixels : ?*anyopaque = null,
    pixel_format : Depth = .RGBA,
};

pub fn createTexture(params : CreateTextureParams) !TextureHandle
{
    var info = TextureInfo{};

    gl.genTextures(1, &info.handle);
    gl.bindTexture(gl.TEXTURE_2D, info.handle);

    gl.texImage2D(gl.TEXTURE_2D,
        0,
        params.depth.toGL(),
        @intCast(c_int, params.width), 
        @intCast(c_int, params.height), 0, 
        @intCast(gl.GLenum, params.pixel_format.toGL()), 
        gl.UNSIGNED_BYTE, 
        params.pixels);

    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, params.min_filter.toGL());
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, params.mag_filter.toGL());

    gl.bindTexture(gl.TEXTURE_2D, 0);

    var handle = try textureLibrary.add(info);
    return handle;
}

pub fn createFramebuffer(params : CreateTextureParams) !FramebufferHandle
{
    var info : FramebufferInfo = undefined;

    gl.genFramebuffers(1, &info.handle);
    errdefer gl.deleteFramebuffers(1, &info.handle);

    gl.bindFramebuffer(gl.FRAMEBUFFER, info.handle);
    defer gl.bindFramebuffer(gl.FRAMEBUFFER, 0);

    info.texture_handle = try createTexture(params);

    const textureInfo = textureLibrary.get(info.texture_handle) catch @panic("invalid handle");
    gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, textureInfo.handle, 0);

    if (gl.checkFramebufferStatus(gl.FRAMEBUFFER) != gl.FRAMEBUFFER_COMPLETE)
        return error.FramebufferInitFailed;

    return try framebufferLibrary.add(info);
}

pub fn bindTexture(handle : TextureHandle) void
{
    const info = textureLibrary.get(handle) catch @panic("invalid handle");

    gl.bindTexture(gl.TEXTURE_2D, info.handle);
}

pub fn getTextureInternalID(handle : TextureHandle) gl.GLuint
{
    const info = textureLibrary.get(handle) catch @panic("invalid handle");

    return info.handle;
}

// if null, unbinds the framebuffer
pub fn bindFramebuffer(handle : ?FramebufferHandle) void
{
    var gl_handle : gl.GLuint = 0;
    if (handle) |handle_not_null|
    {
        const info = framebufferLibrary.get(handle_not_null) catch @panic("invalid handle");

        gl_handle = info.handle;
    }

    gl.bindFramebuffer(gl.FRAMEBUFFER, gl_handle);
}

pub fn getFramebufferTexture(handle : FramebufferHandle) TextureHandle
{
    const info = framebufferLibrary.get(handle) catch @panic("invalid handle");
    return info.texture_handle;
}

pub fn deinit() void
{
    is_init = false;

    for (textureLibrary.items) |textureInfo|
    {
        gl.deleteTextures(1, &textureInfo.handle);
    }
    textureLibrary.deinit();

    for (framebufferLibrary.items) |framebufferInfo|
    {
        gl.deleteFramebuffers(1, &framebufferInfo.handle);
    }
    framebufferLibrary.deinit();
}

test "Texture loading" {
    const window = @import("window.zig");

    var context = try window.Context.init(std.testing.allocator);
    defer context.deinit();

    _ = try loadTexture("data/checker.png", .{});
}

test "Framebuffer" {
    const window = @import("window.zig");
    var context = try window.Context.init(std.testing.allocator);
    defer context.deinit();

    _ = try createFramebuffer(.{.width = 600, .height = 400, .depth = .RGBA});
}