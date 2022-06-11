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
    r : u8 = 0,
    g : u8 = 0,
    b : u8 = 0,
    a : u8 = 0,
};

inline fn indexBitmap(bitmap : []const Rgba, width : isize, x : isize, y : isize) Rgba
{
    return bitmap[@intCast(usize, x + y * width)];
}

const Rect = struct {
    x : i16 = 0,
    y : i16 = 0,
    w : i16 = 0,
    h : i16 = 0,

    pub fn initFromPoints(x0 : i16, y0 : i16, x1 : i16, y1 : i16) Rect
    {
        return .{
            .x = x0,
            .y = y0,
            .w = @maximum(x1 - x0, 0),
            .h = @maximum(y1 - y0, 0),
        };
    }

    pub fn intersection(a : Rect, b : Rect) Rect
    {
        const ax1 = a.x + a.w;
        const ay1 = a.y + a.h;

        const bx1 = b.x + b.w;
        const by1 = b.y + b.h;

        return initFromPoints(
            @maximum(a.x, b.x),
            @maximum(a.y, b.y),
            @minimum(ax1, bx1),
            @minimum(ay1, by1),
        );
    }
};

pub const Bitmap = struct {
    data : []Rgba = undefined,
    width : u16 = undefined,
    height : u16 = undefined,

    // Creates a bitmap with allocated random memory
    pub fn init(in_width : u16, in_height : u16, allocator:Allocator) !Bitmap
    {
        return Bitmap {
            .data = try allocator.alloc(Rgba, @intCast(usize, in_width) * @intCast(usize, in_height)),
            .width = in_width,
            .height = in_height,
        };
    }

    // Take ownership of the in_data pointer
    pub fn initFromU8(in_data : []u8, in_width : u16, in_height : u16) Bitmap
    {
        return Bitmap{
            .data = std.mem.bytesAsSlice(Rgba, in_data),
            .width = in_width,
            .height = in_height,
        };
    }

    pub fn copyFromU8(in_data : []const u8, in_width : u16, in_height : u16, allocator : Allocator) !Bitmap
    {
        return Bitmap{
            .data = try allocator.dupe(Rgba, std.mem.bytesAsSlice(Rgba, in_data)),
            .width = in_width,
            .height = in_height,
        };
    }

    pub fn deinit(self : *Bitmap, allocator : Allocator) void
    {
        allocator.free(self.data);
        self.* = undefined;
    }

    pub fn clear(self : *const Bitmap) void
    {
        std.mem.set(Rgba, self.data, Rgba{});
    }

    pub fn getPixel(self : *const Bitmap, x : u16, y : u16) !Rgba
    {
        if (x >= self.width or y >= self.height) return error.OutOfBounds;
        return self.getPixelUnchecked(x, y);
    }

    pub inline fn getPixelUnchecked(self : *const Bitmap, x : u16, y : u16) Rgba
    {
        return self.idx(x,y).*;
    }

    pub fn setPixelUnchecked(self : *const Bitmap, x : u16, y : u16, pixel : Rgba) void
    {
        self.idx(x,y).* = pixel;
    }

    inline fn idx(self : *const Bitmap, x : u16, y : u16) *Rgba
    {
        const index : usize = @intCast(usize, x) + @intCast(usize, y * self.width); 
        return &self.data[index];
    }

    pub fn debugPrint(self : *const Bitmap) void
    {
        std.debug.print("\n", .{});

        var y : isize = 0;
        while (y < self.height)
        {
            var x : isize = 0;
            while (x < self.width)
            {
                var char = if (self.getPixelUnchecked(@intCast(u16, x), @intCast(u16, y)).a == 0) "." else "#";
                std.debug.print("{s}", .{char});
                x += 1;
            }
            std.debug.print("\n", .{});
            y += 1;
        }
    }

    pub fn blit(self : *Bitmap, source : Bitmap, in_source_rect : Rect, in_dest_x : i16, in_dest_y : i16) void
    {
        _ = self;
        _ = source;

        const dest_rect = 
        Rect.intersection(
            self.getRect(), 
            .{.x = in_dest_x, .y = in_dest_y, .w = @intCast(i16, self.width), .h = @intCast(i16,self.height)}
        );
        
        const source_rect = Rect.intersection(source.getRect(), in_source_rect);

        const min_width = @minimum(source_rect.w, dest_rect.w);
        const min_height = @minimum(source_rect.h, dest_rect.h);

        var y : i16 = 0;
        while (y < min_height)
        {
            var x : i16 = 0;
            while (x < min_width)
            {
                const sx : u16 = @intCast(u16, x + source_rect.x);
                const sy : u16 = @intCast(u16, y + source_rect.y);
                const tx : u16 = @intCast(u16, x + in_dest_x);
                const ty : u16 = @intCast(u16, y + in_dest_y);

                self.setPixelUnchecked(tx, ty, source.getPixelUnchecked(sx, sy));
                x += 1;
            }
            y += 1;
        }
    }

    // Returns a rect representing this bitmap
    pub inline fn getRect(self : Bitmap) Rect
    {
        return .{.x =  0, .y = 0, .w = @intCast(i16, self.width), .h = @intCast(i16,self.height)};
    }

    // return the smallest rectangle that contains all the non fully transparent pixels of this bitmap
    pub fn getTrimmedRect(self : Bitmap) Rect
    {
        const width : isize = @intCast(isize,self.width);
        const height : isize = @intCast(isize,self.height);
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
                if (self.getPixelUnchecked(@intCast(u16, x), @intCast(u16, top)).a != 0)
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
                if (self.getPixelUnchecked(@intCast(u16, left), @intCast(u16, y)).a != 0)
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
                if (self.getPixelUnchecked(@intCast(u16, x), @intCast(u16, bottom)).a != 0)
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
                if (self.getPixelUnchecked(@intCast(u16, right), @intCast(u16, y)).a != 0)
                {
                    break :right_loop;
                }
                y -= 1;
            }
            right -= 1;
        }

        const final_w = @intCast(usize, right - left + 1);
        const final_h = @intCast(usize, bottom - top + 1);

        return .{.x = @intCast(i16, left), .y = @intCast(i16, top), .w = @intCast(i16, final_w), .h = @intCast(i16, final_h)};
    }

    const GetTrimmedCopyReturn = struct{bitmap : Bitmap, rect : Rect};
    // Allocates a copy of the given bitmap, removing as much borders as possible
    pub fn getTrimmedCopy(self : Bitmap, allocator : Allocator) !GetTrimmedCopyReturn
    {
        const trimmed_rect = self.getTrimmedRect();

        var out_bitmap = try Bitmap.init(@intCast(u16, trimmed_rect.w), @intCast(u16, trimmed_rect.h), allocator);
        errdefer out_bitmap.deinit();

        out_bitmap.blit(self, trimmed_rect, 0,0);

        return GetTrimmedCopyReturn{.bitmap = out_bitmap, .rect = trimmed_rect};
    }

};

pub const PngPacker = struct {
    allocator : Allocator = undefined,

    pub fn init(allocator : Allocator) void
    {
        var self = PngPacker{};
        self.allocator = allocator;
        return self;
    }
    
};

test "rect intersection" {
    const a = Rect.initFromPoints(15, 20, 42, 69);
    const b = Rect.initFromPoints(30, 15, 67, 65);
    const inter = Rect.intersection(a, b);

    try std.testing.expectEqual(Rect.initFromPoints(30, 20, 42, 65), inter);
    
}


const test_data align(@alignOf(Rgba)) = "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\xff\xff\xff\xff\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\xff\xff\xff\xff\x00\x00\x00\x00\xff\xff\xff\xff\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\xff\xff\xff\xff\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\xff\xff\xff\xff\x00\x00\x00\x00\xff\xff\xff\xff\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00";


test "build"
{
    var in_bitmap = try Bitmap.copyFromU8(test_data, 8, 8, std.testing.allocator);
    defer in_bitmap.deinit(std.testing.allocator);

    var ret = try in_bitmap.getTrimmedCopy(std.testing.allocator);
    defer ret.bitmap.deinit(std.testing.allocator);

    std.debug.print("\n", .{});

    ret.bitmap.debugPrint();

    try std.testing.expectEqual(@as(i16, 3) , ret.rect.w);
    try std.testing.expectEqual(@as(i16, 4) ,ret.rect.h);
    try std.testing.expectEqual(@as(i16, 3), ret.rect.x);
    try std.testing.expectEqual(@as(i16, 2), ret.rect.y);

    try std.testing.expect(ret.bitmap.getPixelUnchecked(0, 0).a == 0);
    try std.testing.expect(ret.bitmap.getPixelUnchecked(1, 0).a != 0);
}

test "bitmap"
{
    var bitmap =  try Bitmap.init(16,16, std.testing.allocator);
    defer bitmap.deinit(std.testing.allocator);

    bitmap.clear();

    bitmap.setPixelUnchecked(0, 0, .{.a = 255});

    bitmap.debugPrint();
}

test "blit"
{
    var in_bitmap = try Bitmap.copyFromU8(test_data, 8, 8, std.testing.allocator);
    defer in_bitmap.deinit(std.testing.allocator);

    var bitmap =  try Bitmap.init(16,16, std.testing.allocator);
    defer bitmap.deinit(std.testing.allocator);
    bitmap.clear();

    bitmap.blit(in_bitmap, in_bitmap.getRect(), 0, 0);
    bitmap.blit(in_bitmap, in_bitmap.getRect(), 10, 10);

    bitmap.debugPrint();
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