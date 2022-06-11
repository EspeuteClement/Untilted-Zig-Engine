pub usingnamespace c;

const c = @cImport({
    @cInclude("stb_rect_pack.h");
});

const std = @import("std");

pub const Rect = c.stbrp_rect;

pub const Packer = struct {
    // NOTE : ctxt is Heap allocated because internally stb pack rect use pointers to reference other items of the
    // struct. This means ctxt location must remain stable in memory.
    ctxt : *c.stbrp_context = undefined,
    nodes : []c.stbrp_node = undefined,

    pub fn init(width : isize, height : isize, allocator : std.mem.Allocator) !Packer
    {
        var self = Packer{};
        
        self.ctxt = try allocator.create(c.stbrp_context);
        self.ctxt.* = std.mem.zeroes(c.stbrp_context);

        const num_nodes = width + 150;
        self.nodes = try allocator.alloc(c.stbrp_node, @intCast(usize, num_nodes));
        std.mem.set(c.stbrp_node, self.nodes, std.mem.zeroes(c.stbrp_node));

        c.stbrp_init_target(self.ctxt, @intCast(c_int, width), @intCast(c_int, height), self.nodes.ptr, @intCast(c_int, self.nodes.len));
        
        return self;
    }

    pub fn packRects(self : *Packer, rects : []Rect) bool {
        return c.stbrp_pack_rects(self.ctxt, rects.ptr, @intCast(c_int, rects.len)) != 0;
    }

    pub fn deinit(self : *Packer, allocator : std.mem.Allocator) void
    {
        allocator.free(self.nodes);
        allocator.destroy(self.ctxt);
        self.* = undefined;
    }
};
