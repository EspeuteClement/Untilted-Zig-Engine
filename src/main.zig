const std = @import("std");

const window = @import("window.zig");
const build_options = @import("build_options");

const lesson = @import("lessons/04.zig");


pub fn main() !void {
    var context : window.Context = try window.Context.init();
    defer context.deinit();

    try lesson.init(context);
    try context.run(lesson.run);
}