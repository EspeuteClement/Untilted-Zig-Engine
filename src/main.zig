const std = @import("std");

const window = @import("window.zig");
const build_options = @import("build_options");

const lesson = @import("lessons/05.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var allocator = gpa.allocator();
    var context: window.Context = try window.Context.init(allocator);
    defer context.deinit();

    try lesson.init(context);
    try context.run(lesson.run);
}

test "package tests" {
    _ = @import("texture.zig");
    _ = @import("sprite.zig");
    _ = @import("shader.zig");
}
