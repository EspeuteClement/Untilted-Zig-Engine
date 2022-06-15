const std = @import("std");
const serialize = @import("serialize.zig");
const stb_rect_pack = @import("stb_rect_pack.zig");
const zigimg = @import("zigimg");
const sprite = @import("sprite.zig");

const with_test_data = @import("build_options").test_packing_data;

const Allocator = std.mem.Allocator;

const AssetType = enum {
    Texture,
    Sprite,
};

const ChunkHeader = struct {
    asset_type: AssetType = undefined,
    size: usize,
};

pub const PackBuilder = struct {
    allocator: Allocator = undefined,

    pub fn init(allocator: Allocator) void {
        var self = PackBuilder{};
        self.allocator = allocator;

        return self;
    }

    pub fn addTexture() void {}
};

const Rgba = packed struct {
    r: u8 = 0,
    g: u8 = 0,
    b: u8 = 0,
    a: u8 = 0,
};

inline fn indexBitmap(bitmap: []const Rgba, width: isize, x: isize, y: isize) Rgba {
    return bitmap[@intCast(usize, x + y * width)];
}

const Rect = struct {
    x: i16 = 0,
    y: i16 = 0,
    w: i16 = 0,
    h: i16 = 0,

    pub fn initFromPoints(x0: i16, y0: i16, x1: i16, y1: i16) Rect {
        return .{
            .x = x0,
            .y = y0,
            .w = @maximum(x1 - x0, 0),
            .h = @maximum(y1 - y0, 0),
        };
    }

    pub fn intersection(a: Rect, b: Rect) Rect {
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
    data: []Rgba = undefined,
    width: u16 = undefined,
    height: u16 = undefined,

    // Creates a bitmap with allocated random memory
    pub fn init(in_width: u16, in_height: u16, allocator: Allocator) !Bitmap {
        return Bitmap{
            .data = try allocator.alloc(Rgba, @intCast(usize, in_width) * @intCast(usize, in_height)),
            .width = in_width,
            .height = in_height,
        };
    }

    // Take ownership of the in_data pointer
    pub fn initFromU8(in_data: []u8, in_width: u16, in_height: u16) Bitmap {
        return Bitmap{
            .data = std.mem.bytesAsSlice(Rgba, in_data),
            .width = in_width,
            .height = in_height,
        };
    }

    pub fn copyFromU8(in_data: []const u8, in_width: u16, in_height: u16, allocator: Allocator) !Bitmap {
        return Bitmap{
            .data = try allocator.dupe(Rgba, std.mem.bytesAsSlice(Rgba, in_data)),
            .width = in_width,
            .height = in_height,
        };
    }

    pub fn deinit(self: *Bitmap, allocator: Allocator) void {
        allocator.free(self.data);
        self.* = undefined;
    }

    pub fn clear(self: *const Bitmap) void {
        std.mem.set(Rgba, self.data, Rgba{});
    }

    pub fn getPixel(self: *const Bitmap, x: u16, y: u16) !Rgba {
        if (x >= self.width or y >= self.height) return error.OutOfBounds;
        return self.getPixelUnchecked(x, y);
    }

    pub inline fn getPixelUnchecked(self: *const Bitmap, x: u16, y: u16) Rgba {
        return self.idx(x, y).*;
    }

    pub fn setPixelUnchecked(self: *const Bitmap, x: u16, y: u16, pixel: Rgba) void {
        self.idx(x, y).* = pixel;
    }

    inline fn idx(self: *const Bitmap, x: u16, y: u16) *Rgba {
        const index: usize = @intCast(usize, x) + @intCast(usize, y) * @intCast(usize,self.width);
        return &self.data[index];
    }

    pub fn debugPrint(self: *const Bitmap) void {
        std.debug.print("\n", .{});

        var y: isize = 0;
        while (y < self.height) {
            var x: isize = 0;
            while (x < self.width) {
                var char = if (self.getPixelUnchecked(@intCast(u16, x), @intCast(u16, y)).a == 0) "." else "#";
                std.debug.print("{s}", .{char});
                x += 1;
            }
            std.debug.print("\n", .{});
            y += 1;
        }
    }

    pub fn blit(self: *Bitmap, source: Bitmap, in_source_rect: Rect, in_dest_x: i16, in_dest_y: i16) void {
        _ = self;
        _ = source;

        const dest_rect =
            Rect.intersection(self.getRect(), .{ .x = in_dest_x, .y = in_dest_y, .w = @intCast(i16, self.width), .h = @intCast(i16, self.height) });

        const source_rect = Rect.intersection(source.getRect(), in_source_rect);

        const min_width = @minimum(source_rect.w, dest_rect.w);
        const min_height = @minimum(source_rect.h, dest_rect.h);

        var y: i16 = 0;
        while (y < min_height) {
            var x: i16 = 0;
            while (x < min_width) {
                const sx: u16 = @intCast(u16, x + source_rect.x);
                const sy: u16 = @intCast(u16, y + source_rect.y);
                const tx: u16 = @intCast(u16, x + in_dest_x);
                const ty: u16 = @intCast(u16, y + in_dest_y);

                self.setPixelUnchecked(tx, ty, source.getPixelUnchecked(sx, sy));
                x += 1;
            }
            y += 1;
        }
    }

    // Returns a rect representing this bitmap
    pub inline fn getRect(self: Bitmap) Rect {
        return .{ .x = 0, .y = 0, .w = @intCast(i16, self.width), .h = @intCast(i16, self.height) };
    }

    // return the smallest rectangle that contains all the non fully transparent pixels of this bitmap
    pub fn getTrimmedRect(self: Bitmap) Rect {
        const width: isize = @intCast(isize, self.width);
        const height: isize = @intCast(isize, self.height);
        var left: isize = 0;
        var top: isize = 0;
        var right: isize = width - 1;
        var bottom: isize = height - 1;
        var minRight: isize = width - 1;
        var minBottom: isize = height - 1;

        top_loop: while (top <= bottom) {
            var x: isize = 0;
            while (x < width) {
                if (self.getPixelUnchecked(@intCast(u16, x), @intCast(u16, top)).a != 0) {
                    minRight = x;
                    minBottom = top;
                    break :top_loop;
                }
                x += 1;
            }
            top += 1;
        }

        left_loop: while (left < minRight) {
            var y: isize = height - 1;
            while (y > top) {
                if (self.getPixelUnchecked(@intCast(u16, left), @intCast(u16, y)).a != 0) {
                    minBottom = y;
                    break :left_loop;
                }
                y -= 1;
            }
            left += 1;
        }

        bottom_loop: while (bottom > minBottom) {
            var x: isize = width - 1;
            while (x >= left) {
                if (self.getPixelUnchecked(@intCast(u16, x), @intCast(u16, bottom)).a != 0) {
                    minRight = x;
                    break :bottom_loop;
                }
                x -= 1;
            }
            bottom -= 1;
        }

        right_loop: while (right > minRight) {
            var y: isize = bottom;
            while (y >= top) {
                if (self.getPixelUnchecked(@intCast(u16, right), @intCast(u16, y)).a != 0) {
                    break :right_loop;
                }
                y -= 1;
            }
            right -= 1;
        }

        const final_w = @intCast(usize, right - left + 1);
        const final_h = @intCast(usize, bottom - top + 1);

        return .{ .x = @intCast(i16, left), .y = @intCast(i16, top), .w = @intCast(i16, final_w), .h = @intCast(i16, final_h) };
    }

    const GetTrimmedCopyReturn = struct { bitmap: Bitmap, rect: Rect };
    // Allocates a copy of the given bitmap, removing as much borders as possible
    pub fn getTrimmedCopy(self: Bitmap, allocator: Allocator) !GetTrimmedCopyReturn {
        const trimmed_rect = self.getTrimmedRect();

        var out_bitmap = try Bitmap.init(@intCast(u16, trimmed_rect.w), @intCast(u16, trimmed_rect.h), allocator);
        errdefer out_bitmap.deinit();

        out_bitmap.blit(self, trimmed_rect, 0, 0);

        return GetTrimmedCopyReturn{ .bitmap = out_bitmap, .rect = trimmed_rect };
    }
};

pub const PngPacker = struct {
    allocator: Allocator = undefined,
    bitmap_to_pack_arena: std.heap.ArenaAllocator = undefined,

    packing_data: std.MultiArrayList(PackingData) = .{},
    packing_sprite_data : std.ArrayListUnmanaged(sprite.SpriteInfo) = undefined,



    const PackingData = struct {
        bitmap : Bitmap,
        pack_rect : stb_rect_pack.Rect
    };

    pub fn init(allocator: Allocator) PngPacker {
        var self = PngPacker{};
        self.allocator = allocator;
        self.bitmap_to_pack_arena = std.heap.ArenaAllocator.init(allocator);
        self.packing_sprite_data = .{};
        return self;
    }

    pub fn deinit(self: *PngPacker) void {
        self.bitmap_to_pack_arena.deinit();
        self.packing_data.deinit(self.allocator);
        self.packing_sprite_data.deinit(self.allocator);
        self.* = undefined;
    }

    fn preProcessImageForAtlas(self: *PngPacker, dir: std.fs.Dir, file_path: []const u8) !void {
        _ = self;
        _ = dir;

        var bytes = try dir.readFileAlloc(self.allocator, file_path, 4_000_000);
        defer self.allocator.free(bytes);

        var image = try zigimg.Image.fromMemory(self.allocator, bytes);
        defer image.deinit();
        std.debug.assert(image.pixels.? == .rgba32);


        var bitmap = try Bitmap.copyFromU8(try image.rawBytes(), @intCast(u16, image.width), @intCast(u16, image.height), self.allocator);
        defer bitmap.deinit(self.allocator);

        // Note : we don't deinit here because the memory is owned by image, not us

        var trimmed_bitmap_info = try bitmap.getTrimmedCopy(self.bitmap_to_pack_arena.allocator());

        try self.packing_data.append(self.allocator, .{
            .bitmap = trimmed_bitmap_info.bitmap, 
            .pack_rect = .{
                .id = @intCast(c_int, self.packing_data.len),
                .w = @intCast(c_int, trimmed_bitmap_info.rect.w),
                .h = @intCast(c_int, trimmed_bitmap_info.rect.h),
                .x = 0,
                .y = 0,
                .was_packed = 0,
                }
            }
        );

        try self.packing_sprite_data.append(self.allocator,
            .{  .u1 = @intCast(i16, trimmed_bitmap_info.bitmap.width),
                .v1 = @intCast(i16, trimmed_bitmap_info.bitmap.height),
                .x_offset = @intCast(i16, trimmed_bitmap_info.rect.x), 
                .y_offset = @intCast(i16, trimmed_bitmap_info.rect.y),
            });
    }

    // Returns the number of parsed files
    pub fn findAllOfTypeAndDo(self: *PngPacker, dir: std.fs.Dir, extensions: []const []const u8, process: fn (self: *PngPacker, dir: std.fs.Dir, file_path: []const u8) anyerror!void) anyerror!usize {
        var num_files : usize = 0;
        var dir_it = dir.iterate();
        while (try dir_it.next()) |entry| {
            switch (entry.kind) {
                .File => {
                    var matches: bool = m: {
                        if (extensions.len <= 0)
                            break :m false;

                        for (extensions) |ext| {
                            if (std.mem.endsWith(u8, entry.name, ext))
                                break :m true;
                        }
                        break :m false;
                    };

                    if (matches) {
                        try process(self, dir, entry.name);
                        num_files += 1;
                    }
                },
                .Directory => {
                    if (!with_test_data and std.mem.eql(u8, entry.name, "__test_packing_data"))
                        continue;
                    const sub_dir = dir.openDir(entry.name, .{ .iterate = true }) catch continue;
                    num_files += try self.findAllOfTypeAndDo(sub_dir, extensions, process);
                },
                else => continue,
            }
        }

        return num_files;
    }

    const root_dir = "asset-build/";

    pub fn work(self: *PngPacker, path: []const u8) !void {
        try std.fs.cwd().makePath(root_dir);

        var timer = try std.time.Timer.start();

        var content_dir = try std.fs.cwd().openDir(path, .{ .iterate = true });

        const num_files = try self.findAllOfTypeAndDo(content_dir, &[_][]const u8{".png"}, preProcessImageForAtlas);

        std.debug.print("Parsed {d} images in {d:6.4}s\n", .{num_files, @intToFloat(f32, timer.lap()) / std.time.ns_per_s});

        {
            const w = 4096;
            const h = 4096;
            var packer = try stb_rect_pack.Packer.init(w,h, self.allocator);
            defer packer.deinit(self.allocator);

            var out_bitmap = try Bitmap.init(w, h, self.allocator);
            defer out_bitmap.deinit(self.allocator);

            out_bitmap.clear();

            var pack_rects = self.packing_data.items(.pack_rect);
            _ = packer.packRects(pack_rects);

            var texture_id : u16 = 0;
            var i : isize = @intCast(isize, self.packing_data.len)-1;
            while(i >= 0)
            {
                var data : PackingData = self.packing_data.get(@intCast(usize, i));
                if (data.pack_rect.was_packed != 0) {
                    var sprite_data = &self.packing_sprite_data.items[@intCast(usize, data.pack_rect.id)];
                    sprite_data.u0 = @intCast(i16, data.pack_rect.x);
                    sprite_data.v0 = @intCast(i16, data.pack_rect.y);
                    sprite_data.u1 += @intCast(i16, data.pack_rect.x);
                    sprite_data.v1 += @intCast(i16, data.pack_rect.y);
                    sprite_data.texture_id = texture_id;

                    out_bitmap.blit(data.bitmap, data.bitmap.getRect(), @intCast(i16, data.pack_rect.x), @intCast(i16, data.pack_rect.y));
                }

                i -= 1;
            }
            std.debug.print("Packed atlas in {d:6.4}s\n", .{@intToFloat(f32, timer.lap()) / std.time.ns_per_s});

            {
                var array = std.ArrayList(u8).init(self.allocator);
                defer array.deinit();

                var writer = array.writer();

                for (self.packing_sprite_data.items) |data|
                {
                    try serialize.serialise(data, writer);
                }

                try std.fs.cwd().writeFile(root_dir ++ "testData.bin", array.items);
            }
            std.debug.print("Writen sprite data in {d:6.4}s\n", .{@intToFloat(f32, timer.lap()) / std.time.ns_per_s});

            {
                var img = zigimg.Image.init(self.allocator);

                img.width = @intCast(usize, out_bitmap.width);
                img.height = @intCast(usize, out_bitmap.height);

                img.pixels = .{.rgba32 = @ptrCast([*]zigimg.color.Rgba32, out_bitmap.data.ptr)[0..out_bitmap.data.len]};
                //try img.writeToFilePath("testAtlasPack.qoi", .qoi, .{.qoi = .{.colorspace = .linear}});

                var buffer = try self.allocator.alloc(u8, 50_000_000);
                defer self.allocator.free(buffer);
                var out_buffer = try img.writeToMemory(buffer, .qoi, .{.qoi = .{.colorspace = .linear}});

                try std.fs.cwd().writeFile(root_dir ++ "testAtlas.qoi", out_buffer);

                std.debug.print("Finished writing atlas to disk in {d:6.4}s\n", .{@intToFloat(f32, timer.lap()) / std.time.ns_per_s});

            }
        }
    }


};

test "rect intersection" {
    const a = Rect.initFromPoints(15, 20, 42, 69);
    const b = Rect.initFromPoints(30, 15, 67, 65);
    const inter = Rect.intersection(a, b);

    try std.testing.expectEqual(Rect.initFromPoints(30, 20, 42, 65), inter);
}

const test_data align(@alignOf(Rgba)) = "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\xff\xff\xff\xff\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\xff\xff\xff\xff\x00\x00\x00\x00\xff\xff\xff\xff\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\xff\xff\xff\xff\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\xff\xff\xff\xff\x00\x00\x00\x00\xff\xff\xff\xff\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00";

test "build" {
    var in_bitmap = try Bitmap.copyFromU8(test_data, 8, 8, std.testing.allocator);
    defer in_bitmap.deinit(std.testing.allocator);

    var ret = try in_bitmap.getTrimmedCopy(std.testing.allocator);
    defer ret.bitmap.deinit(std.testing.allocator);

    std.debug.print("\n", .{});

    ret.bitmap.debugPrint();

    try std.testing.expectEqual(@as(i16, 3), ret.rect.w);
    try std.testing.expectEqual(@as(i16, 4), ret.rect.h);
    try std.testing.expectEqual(@as(i16, 3), ret.rect.x);
    try std.testing.expectEqual(@as(i16, 2), ret.rect.y);

    try std.testing.expect(ret.bitmap.getPixelUnchecked(0, 0).a == 0);
    try std.testing.expect(ret.bitmap.getPixelUnchecked(1, 0).a != 0);
}

test "bitmap" {
    var bitmap = try Bitmap.init(16, 16, std.testing.allocator);
    defer bitmap.deinit(std.testing.allocator);

    bitmap.clear();

    bitmap.setPixelUnchecked(0, 0, .{ .a = 255 });

    bitmap.debugPrint();
}

test "blit" {
    var in_bitmap = try Bitmap.copyFromU8(test_data, 8, 8, std.testing.allocator);
    defer in_bitmap.deinit(std.testing.allocator);

    var bitmap = try Bitmap.init(16, 16, std.testing.allocator);
    defer bitmap.deinit(std.testing.allocator);
    bitmap.clear();

    bitmap.blit(in_bitmap, in_bitmap.getRect(), 0, 0);
    bitmap.blit(in_bitmap, in_bitmap.getRect(), 10, 10);

    bitmap.debugPrint();
}

test "find all" {
    std.debug.print("\n", .{});
    var pack = PngPacker.init(std.testing.allocator);
    defer pack.deinit();

    try pack.work("data");
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(!gpa.deinit());
    var allocator = gpa.allocator();

    std.debug.print("\n", .{});
    var pack = PngPacker.init(allocator);
    defer pack.deinit();

    try pack.work("data");

}