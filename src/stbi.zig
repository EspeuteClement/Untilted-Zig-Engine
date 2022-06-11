const c = @cImport({
    @cDefine("STBI_ONLY_PNG", "");
    @cInclude("stb_image.h");
    @cInclude("stb_image_write.h");
});

pub usingnamespace c;

const std = @import("std");
const Bitmap = @import("asset_manager.zig").Bitmap;

pub fn loadFromMemory(bytes : []const u8, allocator : std.mem.Allocator) !Bitmap
{
    var x : c_int = undefined;
    var y : c_int = undefined;
    var channels_in_file : c_int = undefined;
    var ptr = c.stbi_load_from_memory(bytes.ptr, @intCast(c_int, bytes.len), &x, &y, &channels_in_file, 4);
    if (ptr == null) return error.StbiLoadFailed;
    defer c.stbi_image_free(ptr);

    std.debug.print("\n Got x = {d} and y = {d}\n", .{x,y});
    
    var bitmap = try Bitmap.copyFromU8(ptr[0..@intCast(usize, x*y*4)], @intCast(u16, x),@intCast(u16, y), allocator);

    return bitmap;
}

pub fn saveToPng(path : [:0]const u8, bitmap : Bitmap) void {
    _ = c.stbi_write_png(path, @intCast(c_int, bitmap.width), @intCast(c_int, bitmap.height), 4, bitmap.data.ptr, 0);
}