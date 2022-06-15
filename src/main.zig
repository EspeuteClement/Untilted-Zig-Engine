const std = @import("std");

const window = @import("window.zig");
const build_options = @import("build_options");

const game = @import("game/game.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(!gpa.deinit());

    var allocator = gpa.allocator();

    var context: window.Context = try window.Context.init(allocator);
    defer context.deinit();

    try game.init(context);
    try context.run(game.run);
}

test "package tests" {
    _ = @import("texture.zig");
    _ = @import("sprite.zig");
    _ = @import("shader.zig");
}
