const std = @import("std");
const Allocator = std.mem.Allocator;

pub const SpriteSheetData = struct {
    data: Data = undefined,
    json_parse_options: std.json.ParseOptions = undefined,

    pub const Data = struct {
        frames: []Frame = undefined,

        pub const Frame = struct {
            frame: Rect = undefined,
            rotated: bool = undefined,
            trimmed: bool = undefined,
            spriteSourceSize: Rect = undefined,
            sourceSize: Rect = undefined,
            duration: i16 = undefined,

            pub const Rect = struct {
                x: i16 = 0,
                y: i16 = 0,
                w: i16 = 0,
                h: i16 = 0,
            };
        };
    };
};

pub fn getSpriteSheetDataFromFile(path: []const u8, allocator: Allocator) !SpriteSheetData {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    var file_text = try file.readToEndAlloc(allocator, 99999999);
    defer allocator.free(file_text);

    var data: SpriteSheetData = .{};
    data.json_parse_options = .{
        .allocator = allocator,
        .ignore_unknown_fields = true,
        .allow_trailing_data = true,
    };

    var stream = std.json.TokenStream.init(file_text);
    data.data = try std.json.parse(SpriteSheetData.Data, &stream, data.json_parse_options);

    return data;
}

pub fn freeSpriteSheetData(data: SpriteSheetData) void {
    std.json.parseFree(SpriteSheetData.Data, data.data, data.json_parse_options);
}
