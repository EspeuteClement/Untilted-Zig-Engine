const std = @import("std");
const gl = @import("gl");
const stb = @import("stbi.zig");

const Allocator = std.mem.Allocator;

const Library = @import("library.zig").Library;

const TextureInfo = struct {
    handle: gl.GLuint = undefined,
};

const TextureLibrary = Library(TextureInfo);
pub const TextureHandle = TextureLibrary.Key;

var textureLibrary : TextureLibrary = undefined;
var paths_to_handle : std.AutoArrayHashMap([]const u8, TextureHandle) = undefined;

pub fn init(allocator : Allocator) !void
{
    textureLibrary = TextureLibrary.init(allocator);
    //paths_to_handle = @TypeOf(paths_to_handle).init(paths_to_handle)
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

    var info = TextureInfo{};

    gl.genTextures(1, &info.handle);
    gl.bindTexture(gl.TEXTURE_2D, info.handle);

    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, x, y, 0, gl.RGBA, gl.UNSIGNED_BYTE, data);

    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);

    gl.generateMipmap(gl.TEXTURE_2D);

    var handle = try textureLibrary.add(info);
    return handle;
}

pub fn bindTexture(handle : TextureHandle) void
{
    const info = textureLibrary.get(handle) catch @panic("invalid handle");

    gl.bindTexture(gl.TEXTURE_2D, info.handle);
}

pub fn deinit() void
{
    for (textureLibrary.items) |textureInfo|
    {
        gl.deleteTextures(1, &textureInfo.handle);
    }

    textureLibrary.deinit();
}

test "Texture loading" {
    const window = @import("window.zig");

    var context = try window.Context.init(std.testing.allocator);
    defer context.deinit();

    try init(std.testing.allocator);
    defer deinit();

    _ = try loadTexture("data/checker.png", .{});
}