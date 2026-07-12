const std = @import("std");
const assert = @import("std").debug.assert;

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
}
