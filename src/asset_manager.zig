const std = @import("std");
const serialize = @import("serialize.zig");
const window = @import("window.zig");

const Allocator = std.mem.Allocator;

const AssetType = enum {
    Texture,
    Sprite,
};

const ChunkHeader = struct {
    asset_type : AssetType = undefined,
    size : usize,
};

pub const PackBuilder = struct {
    allocator : Allocator = undefined,

    pub fn init(allocator : Allocator) void
    {
        var self = PackBuilder{};
        self.allocator = allocator;

        return self;
    }

    pub fn addTexture() void {

    }
};

const Rgba = packed struct {
    r : u8,
    g : u8,
    b : u8,
    a : u8,
};

inline fn indexBitmap(bitmap : []const Rgba, width : isize, x : isize, y : isize) Rgba
{
    return bitmap[@intCast(usize, x + y * width)];
}

pub const PngPacker = struct {
    allocator : Allocator = undefined,

    pub fn init(allocator : Allocator) void
    {
        var self = PngPacker{};
        self.allocator = allocator;
        return self;
    }

    pub const trimBitmapReturn = struct {bitmap : []Rgba, x_offset : usize, y_offset : usize, width : usize, height : usize};
    // Allocates a copy of the given bitmap, removing as much borders as possible
    pub fn trimBitmap(in_data : []const u8, in_width : usize, in_height : usize, allocator : Allocator) !trimBitmapReturn
    {
        const bitmap = std.mem.bytesAsSlice(Rgba, in_data);
        const width : isize = @intCast(isize,in_width);
        const height : isize = @intCast(isize,in_height);
        var left : isize = 0;
        var top : isize = 0;
        var right : isize = width - 1;
        var bottom : isize = height - 1;
        var minRight : isize = width - 1;
        var minBottom : isize = height - 1;

        top_loop:
        while(top <= bottom)
        {
            var x : isize = 0;
            while(x < width)
            {
                if (indexBitmap(bitmap, width, x, top).a != 0)
                {
                    minRight = x;
                    minBottom = top;
                    break :top_loop;
                }
                x += 1;
            }
            top += 1;
        }

        left_loop:
        while (left < minRight)
        {
            var y : isize = height - 1;
            while(y > top)
            {
                if (indexBitmap(bitmap, width, left, y).a != 0)
                {
                    minBottom = y;
                    break :left_loop;
                }
                y -= 1;
            }
            left += 1;
        }

        bottom_loop:
        while (bottom > minBottom)
        {
            var x : isize = width - 1;
            while(x >= left)
            {
                if (indexBitmap(bitmap, width, x, bottom).a != 0)
                {
                    minRight = x;
                    break :bottom_loop;
                }
                x -= 1;
            }
            bottom -= 1;
        }

        right_loop:
        while (right > minRight)
        {
            var y : isize = bottom;
            while(y >= top)
            {
                if (indexBitmap(bitmap, width, right, y).a != 0)
                {
                    break :right_loop;
                }
                y -= 1;
            }
            right -= 1;
        }

        const final_w = @intCast(usize, right - left + 1);
        const final_h = @intCast(usize, bottom - top + 1);
        const dest_buffer = try allocator.alloc(Rgba, @intCast(usize, final_w * final_h));

        {
            var y : usize = 0;

            while(y < final_h)
            {
                var x : usize = 0;
                while(x < final_w)
                {
                    dest_buffer[y*final_w + x] = indexBitmap(bitmap, width, @intCast(isize, x)+left, @intCast(isize, y)+top);
                    x +=1;
                }

                y += 1;
            }
        }

        return trimBitmapReturn{.bitmap = dest_buffer, .x_offset = @intCast(usize, left), .y_offset = @intCast(usize, top), .width = @intCast(usize, final_w), .height = @intCast(usize, final_h)};
    }
};


test "build"
{
    const data align(@alignOf(Rgba)) = "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\xff\xff\xff\xff\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\xff\xff\xff\xff\x00\x00\x00\x00\xff\xff\xff\xff\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\xff\xff\xff\xff\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\xff\xff\xff\xff\x00\x00\x00\x00\xff\xff\xff\xff\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00";

    var ret = try PngPacker.trimBitmap(data, 8, 8, std.testing.allocator);
    defer std.testing.allocator.free(ret.bitmap);

    std.debug.print("\n", .{});

    var y : isize = 0;
    while (y < ret.height)
    {
        var x : isize = 0;
        while (x < ret.width)
        {
            var char = if (indexBitmap(ret.bitmap, @intCast(isize, ret.width), x, y).a == 0) "." else "#";
            std.debug.print("{s}", .{char});
            x += 1;
        }
        std.debug.print("\n", .{});
        y += 1;
    }

    try std.testing.expectEqual(@as(usize, 3) , ret.width);
    try std.testing.expectEqual(@as(usize, 4) ,ret.height);
    try std.testing.expectEqual(@as(usize, 3), ret.x_offset);
    try std.testing.expectEqual(@as(usize, 2), ret.y_offset);

    try std.testing.expect(indexBitmap(ret.bitmap, @intCast(isize, ret.width), 0, 0).a == 0);
    try std.testing.expect(indexBitmap(ret.bitmap, @intCast(isize,ret.width), 1, 0).a != 0);

}

pub fn main() !void
{
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var allocator = gpa.allocator();
    var context : window.Context = try window.Context.init(allocator);
    defer context.deinit();

    try context.run(run);
}

pub fn run(ctxt : window.Context) !void
{
    _ = ctxt;
}