const std = @import("std");
const serialize = @import("serialize.zig");

const Allocator = std.mem.Allocator;

const AssetType = enum {
    Texture,
    Sprite,
};

const RefEntry = struct {
    file_pos : usize,
    file_size : usize,
};


pub const PackBuilder = struct {
    std.StringArrayHashMapUnmanaged()

    pub fn init(allocator : Allocator) void
    {

    }
};