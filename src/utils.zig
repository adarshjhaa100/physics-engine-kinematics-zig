const std = @import("std");

pub const GameConfigKeys = enum { game_screen_width, game_screen_height, game_target_fps, game_background_color, game_background_texture, physics_earth_gravity };

pub const GameConfigValue = struct {
    key_value: []const u8,
    key_type: enum { int, float, string },
};

fn GameConfigMapInit(allocator: std.mem.Allocator) !std.AutoHashMap(GameConfigKeys, GameConfigValue) {
    var game_config_map_init =
        std.AutoHashMap(GameConfigKeys, GameConfigValue).init(allocator);

    const INT_KEYS = [_]GameConfigKeys{ .game_screen_width, .game_screen_height, .game_target_fps };
    const STRING_KEYS = [_]GameConfigKeys{.game_background_color};
    const FLOAT_KEYS = [_]GameConfigKeys{.physics_earth_gravity};

    for (INT_KEYS) |value| {
        try game_config_map_init.put(value, .{ .key_type = .int, .key_value = undefined });
    }
    for (FLOAT_KEYS) |value| {
        try game_config_map_init.put(value, .{ .key_type = .float, .key_value = undefined });
    }
    for (STRING_KEYS) |value| {
        try game_config_map_init.put(value, .{ .key_type = .string, .key_value = undefined });
    }

    return game_config_map_init;
}

// Read file at pat based on config list defined
pub fn ReadConfigFile(allocator: std.mem.Allocator) !void {
    var game_config_map = try GameConfigMapInit(allocator);
    var iterator = game_config_map.keyIterator();
    while (iterator.next()) |key| {
        const actualKey = key.*;
        std.debug.print("\nKey: {any}, Value: {any}\n", .{ actualKey, game_config_map.get(actualKey) });
    }

    // var file_buffer:[1024]
    // try std.Io.File.read
    // s
    // const file_content = std.Io.File(file: File,     io: Io, buffer: []u8);
}
