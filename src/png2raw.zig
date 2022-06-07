const std = @import("std");
const stb = @import("stbi.zig");

pub fn main() !void
{
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var allocator = gpa.allocator();


    var args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len != 2)
        return error.BadArgCount;
    
    var x : c_int = undefined;
    var y : c_int = undefined;
    var n : c_int = undefined;

    
    var data : [*c]u8 = stb.stbi_load(args[1], &x, &y, &n, 4);
    if (data == null)
        return error.StbiLoadFail;

    defer stb.stbi_image_free(data);

    std.debug.print("\"", .{});
    for (data[0..@intCast(usize, x*y*n)]) |byte|
    {
        std.debug.print("\\x{x:0>2}", .{byte});
    }
    std.debug.print("\"", .{});

}