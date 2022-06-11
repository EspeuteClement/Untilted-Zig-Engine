const std = @import("std");

pub fn deserialise(comptime T: type, reader: anytype) !T {
    var value: T = undefined;
    const typeInfo = @typeInfo(T);

    inline for (typeInfo.Struct.fields) |field| {
        try ReadWriteFunc(field.field_type, .Read, &@field(value, field.name), reader);
    }

    return value;
}

pub fn serialise(value: anytype, reader: anytype) !void {
    const T = @TypeOf(value);
    const typeInfo = @typeInfo(T);

    inline for (typeInfo.Struct.fields) |field| {
        try ReadWriteFunc(field.field_type, .Write, @field(value, field.name), reader);
    }
}

const ReadWrite = enum(u8) {
    Write,
    Read,
};

inline fn ReadWriteFunc(comptime T: type, comptime mode: ReadWrite, value: brk: {
    switch (mode) {
        .Read => break :brk *T,
        .Write => break :brk T,
    }
}, readwritter: anytype) !void {
    switch (@typeInfo(T)) {
        .Int => {
            switch (mode) {
                .Write => try readwritter.writeIntLittle(T, value),
                .Read => value.* = try readwritter.readIntLittle(T),
            }
        },
        .Enum => |enum_info| {
            switch (mode) {
                .Write => try readwritter.writeIntLittle(enum_info.tag_type, @enumToInt(value)),
                .Read => value.* = @intToEnum(T, try readwritter.readIntLittle(enum_info.tag_type)),
            }
        },
        else => @compileError("Unsuported type : " ++ @typeName(T)),
    }
}

test "Read Ints" {
    const TestEnum = enum(u16) {
        foo,
        bar = 0xFF77,
    };

    const TestStruct = struct {
        a: u8 = 123,
        b: u16 = 456,
        c: u32 = 98765432,
        d: u24 = 777,
        e: TestEnum = .bar,
    };

    var initialValues: TestStruct = .{};

    var mem: [128]u8 = undefined;
    var stream = std.io.fixedBufferStream(&mem);

    try serialise(initialValues, stream.writer());

    stream.reset();

    var deserializedValues = try deserialise(TestStruct, stream.reader());

    try std.testing.expectEqual(initialValues, deserializedValues);
}
