const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn Library(comptime T : type) type {
    return struct {
        items : []T = &[_]T{},

        last_element : u32 = 0,
        allocator : Allocator = undefined,

        pub fn init(allocator : Allocator) Self
        {
            return Self{
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *Self) void
        {
            self.allocator.free(self.items);
            self.* = undefined;
        }

        pub fn get(self : *const Self, key : Key) !T
        {
            if (key.index < self.items.len)
            {
                return self.items[key.index];
            }
            return error.OutOfBounds;
        }

        pub fn add(self : *Self, item : T) !Key
        {
            try self.ensureSize(@intCast(u32, self.last_element+1));
            self.items[self.last_element] = item;
            const key = Key{.index = self.last_element};

            self.last_element += 1;

            return key;
        }

        pub fn ensureSize(self :*Self, size : u32) !void
        {
            if (self.items.len <= size)
            {
                const new_size = std.math.ceilPowerOfTwo(usize, @intCast(usize, size)) catch return error.OutOfMemory;
                self.items = try self.allocator.reallocAtLeast(self.items, new_size);
            }
        }

        pub const Key = struct {
            index : u32,
        };
        
        pub const ElementType = T;
        pub const Self = @This();
    };
}

test "basic usage" {
    var lib = Library(u32).init(std.testing.allocator);
    defer lib.deinit();

    const item : u32 = 42;

    const key1 = try lib.add(item);
    const key2 = try lib.add(99);
    const key3 = try lib.add(1);

    try std.testing.expectEqual(try lib.get(key1), 42);
    try std.testing.expectEqual(try lib.get(key2), 99);
    try std.testing.expectEqual(try lib.get(key3), 1);

    var keys : [100]@TypeOf(lib).Key = undefined;
    for (keys) |*key, i|
    {
        key.* = try lib.add(@intCast(u32, i));
    }

    for (keys) |key, i|
    {
        try std.testing.expectEqual(try lib.get(key), @intCast(u32, i));
    }

    try std.testing.expectEqual(try lib.get(key1), 42);
    try std.testing.expectEqual(try lib.get(key2), 99);
    try std.testing.expectEqual(try lib.get(key3), 1);
}