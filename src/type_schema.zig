const std = @import("std");

pub const AppState = struct {
    fba: std.heap.FixedBufferAllocator,
    game_screen_width: i32,
    game_screen_height: i32,
    game_target_fps: i32,
    game_background_color: [3]u8,
    game_background_texture: []const u8,
    physics_earth_gravity: f32,
};
