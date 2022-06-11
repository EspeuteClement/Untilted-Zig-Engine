// Metaprogramming lib
const std = @import("std");

pub fn enumNames(comptime E: type) [@typeInfo(E).Enum.fields.len][]const u8 {
    comptime {
        var paths: [@typeInfo(E).Enum.fields.len][]const u8 = undefined;
        for (@typeInfo(E).Enum.fields) |field, i| {
            paths[i] = field.name;
        }
        return paths;
    }
}

test "Enum Names" {
    const TestEnum = enum { hello, world, foo, bar };
    const names = enumNames(TestEnum);

    try std.testing.expectEqualStrings(names[0], "hello");
    try std.testing.expectEqualStrings(names[1], "world");
    try std.testing.expectEqualStrings(names[2], "foo");
    try std.testing.expectEqualStrings(names[3], "bar");
}
