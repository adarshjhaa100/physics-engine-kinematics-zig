const std = @import("std");
const builtin = @import("builtin");
const assert = @import("std").debug.assert;
const c_sdl = @import("common.zig").c_sdl;
const AppState = @import("type_schema.zig").AppState;

// Ownership local or global???? ( allocator needs to be locally as well )
// We'll have list of allocators which we'll free later
pub const GameConfigKey = enum(u8) {
    game_screen_width,
    game_screen_height,
    game_target_fps,
    game_background_color, // hex value
    game_background_texture,
    physics_earth_gravity,
    // Count of fields
    pub const count = @typeInfo(GameConfigKey).@"enum".fields.len;
};

pub const GameConfigVarValue = union(enum) {
    int: i32,
    float: f32,
    string: [64]u8,
};

// Key val where key is int val of enum GameConfigKey
pub const GameConfigMap = [GameConfigKey.count]GameConfigVarValue;

pub fn sliceToFixedString(comptime len: usize, slice: []const u8) [len]u8 {
    var buff: [len]u8 = undefined;
    @memset(&buff, 0);
    @memcpy(buff[0..slice.len], slice);
    return buff;
}

// blk: defines anonymous function
// internally fn blk() {return map;}
pub const game_config_default_map: GameConfigMap = blk: {
    var mp: GameConfigMap = undefined;
    mp[@intFromEnum(GameConfigKey.game_screen_width)] =
        .{ .int = 800 };
    mp[@intFromEnum(GameConfigKey.game_screen_height)] =
        .{ .int = 600 };
    mp[@intFromEnum(GameConfigKey.game_target_fps)] =
        .{ .int = 60 };
    mp[@intFromEnum(GameConfigKey.game_background_color)] =
        .{ .string = sliceToFixedString(64, "blue") };
    mp[@intFromEnum(GameConfigKey.game_background_texture)] =
        .{ .string = sliceToFixedString(64, "texture") };
    mp[@intFromEnum(GameConfigKey.physics_earth_gravity)] =
        .{ .float = 9.81 };
    break :blk mp;
};

// Read file at pat based on config list defined
// ~ 200 characters of config file
pub fn ReadConfigFile(init: std.process.Init, allocator: std.mem.Allocator) !GameConfigMap {
    // create copy of value
    var game_config_map = game_config_default_map;

    // Current path
    const io = init.io;
    var buff = try allocator.alloc(u8, std.fs.max_path_bytes);
    const cwd = std.Io.Dir.cwd(); // returns a handle to cwd
    const pathLen = try std.Io.Dir.realPathFile(cwd, io, ".", buff);

    // read file
    // Open File
    // Default Values set?
    const file =
        try cwd.openFile(io, "./src/config/gameInit", .{ .mode = .read_only });
    defer file.close(io);

    // 2. Create reader(reader memoizes key info abt file) with buffer
    const reader_buff = try allocator.alloc(u8, 4096);
    var reader = file.reader(io, reader_buff); // attach with file

    // Iterate over line by line
    while (try reader.interface.takeDelimiter('\n')) |line| {
        // Iterator for "splitting" (it goes over string and stores index of split chars and returns slice in between till line end)
        var split_iterator = std.mem.splitScalar(u8, line, '=');
        // key ,get next "token" separated by separator
        if (split_iterator.next()) |verified_key| {
            const key_enum =
                std.meta.stringToEnum(GameConfigKey, verified_key);
            if (key_enum) |key_enum_eval| {
                std.debug.print("\nInserting for key: {any}", .{key_enum_eval});
                const existing = game_config_map[@intFromEnum(key_enum_eval)];
                if (split_iterator.next()) |value| {
                    // dupe required since value_ptr.key_value "value" here is just a reference in backend
                    switch (existing) {
                        // NOTE: no capture here since we're assigning value
                        .int => game_config_map[@intFromEnum(key_enum_eval)] =
                            .{ .int = try std.fmt.parseInt(i32, value, 10) },
                        .float => game_config_map[@intFromEnum(key_enum_eval)] =
                            .{ .float = try std.fmt.parseFloat(f32, value) },
                        .string => {
                            game_config_map[@intFromEnum(key_enum_eval)] =
                                .{ .string = sliceToFixedString(64, value) };
                        },
                    }
                }
            }
        }
    }

    for (game_config_map, 0..) |value, index| {
        const key: GameConfigKey = @enumFromInt(index);
        std.debug.print("\nkey: {any}, \n", .{key});
        switch (value) {
            // This |i| is called capture.
            .int => |i| std.debug.print("\nInt value: {d}\n", .{i}),
            .float => |f| std.debug.print("\nFloat value: {d}\n", .{f}),
            .string => |s| std.debug.print("\nString value: {s}\n", .{s}),
        }
    }

    std.debug.print("\nRead CWD: {s}", .{buff[0..pathLen]});

    return game_config_map;
}

pub fn HexToRGBCol(hex_color: []const u8) ![3]u8 {
    assert(hex_color.len == 6); // Valid hex color

    var rgb_col: [3]u8 = undefined;
    const value = try std.fmt.parseInt(u24, hex_color, 16);
    // 255 is 0xFF which is used to make zero rest of the digits
    rgb_col[0] = @intCast((value >> 16) & 255);
    rgb_col[1] = @intCast((value >> 8) & 255);
    rgb_col[2] = @intCast((value >> 0) & 255);

    return rgb_col;
}

// render maze given input bitmap 1-d array and output
pub fn render_maze(bitmap_arr: []const u8, grid_dimensions: [2]u8, app_state: *AppState, renderer: ?*c_sdl.SDL_Renderer) void {
    // setup grid
    const height_cell: f32 = @floatFromInt(@divFloor(app_state.game_screen_height, grid_dimensions[1]));
    const width_cell: f32 = @floatFromInt(@divFloor(app_state.game_screen_width, grid_dimensions[0]));
    const cells_per_row: u8 = grid_dimensions[0];

    std.debug.print("\nGrid Dimensions: h, w {any}, {any}\n", .{ height_cell, width_cell });

    for (bitmap_arr, 0..) |cell, index| {
        if (cell == 1) {
            const xpos: f32 = @floatFromInt(index % cells_per_row);
            const ypos: f32 = @floatFromInt(@divFloor(index, cells_per_row));
            const grid_cell: c_sdl.SDL_FRect = .{
                .h = height_cell,
                .w = width_cell,
                .x = width_cell * xpos,
                .y = height_cell * ypos,
            };

            std.debug.print("Grid cell to paint: i,j = {d},{d}, x, y = {d}, {}\n", .{ xpos, ypos, width_cell * xpos, height_cell * ypos });
            _ = c_sdl.SDL_SetRenderDrawColor(renderer, 255, 255, 255, 1);
            _ = c_sdl.SDL_RenderRect(renderer, &grid_cell);
            // _ = c.SDL_SetRenderDrawColor(renderer, 160, 170, 90, 1);
            // _ = c.SDL_RenderFillRect(renderer, &grid_cell);
        }
    }
}
