const std = @import("std");

const enabled : bool = @import("build_options").with_profiling;

fn ProfileZone(comptime src : std.builtin.SourceLocation, comptime name : ?[]const u8) type {
    if (enabled) {
        return struct {
            timer : std.time.Timer = undefined,

            pub fn _begin() Self {
                return .{
                    .timer = std.time.Timer.start() catch @panic("couldn't read time"),
                };
            }

            pub fn end(self : *Self) void {
                var time = self.timer.read();
                std.debug.print(print_name ++ " took {d:.4} ms\n", .{@intToFloat(f32, time) / std.time.ns_per_ms});
            }

            const print_name = brk: {
                var base_name = src.fn_name;
                if (name) |name_not_null| {
                    base_name = base_name ++ ":" ++ name_not_null;
                }
                else {
                    base_name = base_name ++ ":" ++ std.fmt.comptimePrint("{d}", .{src.line});
                }
                break :brk base_name;
            };

            const Self = @This();
        };
    }
    else {
        return struct {
            pub inline fn _begin() Self {
                return .{};
            }

            pub inline fn end(self : *Self) void {
                _ = self;
            }

            const Self = @This();
        };
    }
}

// usage : `var prof = profile.begin(@src(), "bufferData"); defer prof.end();`

pub fn begin(comptime src : std.builtin.SourceLocation, comptime name : ?[]const u8) ProfileZone(src, name) {
    return ProfileZone(src, name)._begin();
}