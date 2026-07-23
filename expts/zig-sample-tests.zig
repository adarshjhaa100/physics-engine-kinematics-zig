const std = @import("std");
const assert = @import("std").debug.assert;

// Tagged union for variable TYPE (a var of this type occupies max(bytes occupied by each type))
const ValVar =
    union(enum) { int: i32, float: f32, string: []const u8 };

test "for basic" {
    const items = [_]i32{ 1, 2, 3, 4, 5 }; // const array declaration with non fixed size
    const items2: [5]i32 = .{ 1, 2, 3, 4, 5 }; // explicit type casting

    assert(std.mem.eql(i32, &items, &items2)); // [_]i32 is arr and mem.eql expects slice

    const slice1 = items[2..items2.len]; // slice must have end index <= size

    // For loop with index (need to mention 2nd range)
    // 2nd "capture value"
    // lengths must be equal
    // 2nd is iteration over range
    for (slice1, 0..) |value, i| {
        std.debug.print("i = {d}, val = {d}\n", .{ i, value });
    }

    // Vector - SIMD instructions
    const vec1 = @Vector(4, i32){ 3, 5, 6, 7 };
    const vec2: @Vector(4, i32) = items[0..4].*; // array(.* converts slice to arr) to vector type coercion
    const vecSum = vec1 + vec2;
    const resSumScalar: [4]i32 = vecSum;

    for (resSumScalar) |value| {
        std.debug.print("Sum : {d}, ", .{value});
    }

    // Tagged union for variable type
    const int_val_var: ValVar = .{ .int = 34 };
    const float_val_var: ValVar = .{ .float = 32.12 };
    const string_val_var: ValVar = .{ .string = "Hello, Zig" };

    const val_var_arr: [3]ValVar = [_]ValVar{ int_val_var, float_val_var, string_val_var };

    const val_var_size = @sizeOf(ValVar);
    const val_var_alignment = @alignOf(ValVar);
    std.debug.print("\nVal Vars: size: {d}, alignment: {d}\n", .{ val_var_size, val_var_alignment });

    for (val_var_arr) |val_var| {
        switch (val_var) {
            // This |i| is called capture.
            .int => |i| std.debug.print("\nInt value: {d}", .{i}),
            .float => |f| std.debug.print("\nFloat value: {d}", .{f}),
            .string => |s| std.debug.print("\nString value: {s}\n", .{s}),
        }
    }
}
