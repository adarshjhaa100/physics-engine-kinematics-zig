const std = @import("std");
const builtin = @import("builtin");

pub const GameConfigKeys = enum { game_screen_width, game_screen_height, game_target_fps, game_background_color, game_background_texture, physics_earth_gravity };

pub const KeyTypes = enum { int, float, string };

pub const GameConfigValue = struct {
    key_value: []const u8,
    key_type: KeyTypes,
};

fn GameConfigMapInit(allocator: std.mem.Allocator) !std.AutoHashMap(GameConfigKeys, GameConfigValue) {
    var game_config_map_init =
        std.AutoHashMap(GameConfigKeys, GameConfigValue).init(allocator);

    const INT_KEYS = [_]GameConfigKeys{ .game_screen_width, .game_screen_height, .game_target_fps };
    const STRING_KEYS = [_]GameConfigKeys{ .game_background_color, .game_background_texture };
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
pub fn ReadConfigFile(init: std.process.Init, allocator: std.mem.Allocator) !void {
    var game_config_map = try GameConfigMapInit(allocator);

    // Current path
    const io = init.io;
    var buff = try allocator.alloc(u8, std.fs.max_path_bytes);
    const cwd = std.Io.Dir.cwd();
    const pathLen = try std.Io.Dir.realPathFile(cwd, io, ".", buff);

    // read file
    // Open File
    const file = try cwd.openFile(io, "./src/config/gameInit", .{ .mode = .read_only });
    defer file.close(io);

    // 2. Create reader(reader memoizes key info abt file) with buffer
    const reader_buff = try allocator.alloc(u8, 4096);
    var reader = file.reader(io, reader_buff); // attach with file

    // Iterate over line by line
    while (try reader.interface.takeDelimiter('\n')) |line| {
        // Iterator for "splitting" (it goes over string and stores index of split chars and returns slice in between till line end)
        var split_iterator = std.mem.splitScalar(u8, line, '=');

        // key
        if (split_iterator.next()) |verified_key| {
            const key_enum = std.meta.stringToEnum(GameConfigKeys, verified_key);
            if (key_enum) |key_enum_eval| {
                std.debug.print("\nInserting for key: {any}", .{key_enum_eval});

                const existing = try game_config_map.getOrPut(key_enum_eval);
                if (existing.found_existing) {
                    if (split_iterator.next()) |value| {
                        // try game_config_map.put(key_enum_eval, .{ .key_type = existing.value_ptr.key_type, .key_value = value });
                        allocator.free(existing.value_ptr.key_value);
                        existing.value_ptr.key_value = try allocator.dupe(u8, value);
                    }
                }
            }
        }
    }

    var iterator = game_config_map.keyIterator();
    while (iterator.next()) |key| {
        const actualKey = key.*;
        std.debug.print("\nKey: {any}, Value: {s}\n", .{ actualKey, game_config_map.get(actualKey).?.key_value });
    }

    std.debug.print("\nRead CWD: {s}", .{buff[0..pathLen]});
}
