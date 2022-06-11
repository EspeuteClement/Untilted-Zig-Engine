const gl = @import("gl");
const window = @import("../window.zig");

pub fn init(ctxt: window.Context) !void {
    _ = ctxt;
}

pub fn run(ctxt: window.Context) !void {
    _ = ctxt;

    gl.clearColor(1, 0, 1, 1);
    gl.clear(gl.COLOR_BUFFER_BIT);
}
