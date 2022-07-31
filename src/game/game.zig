const std = @import("std");
const gl = @import("gl");
const window = @import("../window.zig");
const glhelp = @import("../glhelp.zig");
const aseprite = @import("../aseprite.zig");
const texture = @import("../texture.zig");
const sprite = @import("../sprite.zig");
const shader = @import("../shader.zig");

const profile = @import("../profile.zig");

var program: gl.GLuint = undefined;

var vertex_array_object: gl.GLuint = undefined;
var vertex_buffer_object: gl.GLuint = undefined;
var element_buffer_object: gl.GLuint = undefined;
var instance_vertex_buffer_object: gl.GLuint = undefined;
var camera_uniform: gl.GLint = undefined;
var texture_handle: texture.TextureHandle = undefined;
var sprite_handle: sprite.Spr = .@"leneth";


const ShaderUniform = struct {
    uCamera: shader.Camera = undefined,
};

var batch: sprite.Batch = undefined;

var game_shader: shader.Shader(ShaderUniform) = undefined;

var actors : []Actor = undefined;
const max_actors = 100_000;


const Actor = struct {
    x : f32,
    y : f32,
    vx : f32,
    vy : f32,
};


pub fn init(ctxt: window.Context) !void {
    _ = ctxt;

    batch = try sprite.Batch.init(ctxt.allocator);
    errdefer batch.deinit();
    batch.texture_handle = try texture.loadTexture("asset-build/testAtlas.qoi", .{});

    game_shader = @TypeOf(game_shader).init(try glhelp.buildProgram(@embedFile("game.vert"), @embedFile("game.frag")));

    var rand = std.rand.DefaultPrng.init(0);
    
    const speed = 1.0;
    var random = rand.random();
    actors = try ctxt.allocator.alloc(Actor, max_actors);
    errdefer ctxt.allocator.free(actors);

    for (actors) |*actor| {
        actor.x = random.float(f32) * @intToFloat(f32, ctxt.data.config.game_width);
        actor.y = random.float(f32) * @intToFloat(f32,ctxt.data.config.game_height);

        var angle = random.float(f32) * std.math.tau;

        actor.vx = speed * @sin(angle);
        actor.vy = speed * @cos(angle);
    }
}

pub fn deinit(ctxt: window.Context) void {
    _ = ctxt;
    batch.deinit();
    game_shader.deinit();
    ctxt.allocator.free(actors);
}

pub var time: usize = 0;

pub fn run(ctxt: window.Context) !void {
    _ = ctxt;

    time += 1;
}

const static = false;
var first_time = true;

pub fn draw(ctxt: window.Context) !void {
    var prof = profile.begin(@src(), "bufferData"); defer prof.end();

    const w = @intToFloat(f32, ctxt.data.config.game_width);
    const h = @intToFloat(f32, ctxt.data.config.game_height);
    const fTime = @intToFloat(f32, time);

    //std.debug.print("{d}\n", .{time});

    //try batch.drawSimple(.@"leneth", @divTrunc(time, 10) % 4, 150.0, 150.0);

    // var i: usize = 0;
    // while (i < 100) {
    //     const fi = @intToFloat(f32, i);
    //     try batch.drawSimple(.{.index = 1}, 200.0 + 100 * std.math.sin(fTime / 100.0 + fi) + std.math.sin(fTime / 500 + fi * 743.0) * 300.0, 200.0 + 100 * std.math.cos(fTime / 100.0 + fi) + std.math.cos(fTime / 500 + fi * 114.0) * 200.0);
    //     i += 1;
    // }

    const spr = try sprite.spriteLibrary.get(.{.index = 1});

    if (!static or first_time)
    {
        first_time = false;
        for (actors) |*actor| {
            const new_x = actor.x + actor.vx; 
            if (new_x > @intToFloat(f32,ctxt.data.config.game_width) or new_x < 0) {
                actor.vx *= -1;
            }
            actor.x += actor.vx;

            const new_y = actor.y + actor.vy; 
            if (new_y > @intToFloat(f32,ctxt.data.config.game_height) or new_y < 0) {
                actor.vy *= -1;
            }
            actor.y += actor.vy;

            batch.drawSpriteInfo(spr, actor.x, actor.y) catch unreachable;
        }
    }


    gl.clearColor(0, 1, 1, 1);
    gl.clear(gl.COLOR_BUFFER_BIT);

    game_shader.bind(.{ .uCamera = shader.makeCamera(0.0 + @cos(fTime/60.0) * 0, 0.0 + @sin(fTime/60.0) * 0, w, h) });

    if (static) {
        try batch.renderNoClear();
    }
    else {
        try batch.render();
    }
}
