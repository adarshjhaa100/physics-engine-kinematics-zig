const AppState = @import("../type_schema.zig").AppState;
const c = @import("../common.zig").c_sdl;
const std = @import("std");
const render_maze = @import("../utils.zig").render_maze;

pub const GRID_DIMENSIONS: [2]u8 = [_]u8{ 8, 6 };
// Flattened array in
pub const GRID_MAZE = [_]u8{ 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1 };

// pub const GRID_DIMENSIONS: [2]u8 = [_]u8{ 4, 3 };
// // Flattened array in
// pub const GRID_MAZE = [_]u8{ 1, 1, 1, 1, 0, 1, 0, 0, 1, 1, 1, 1 };

///Setup grid in matrix format with obstacles and path.
/// Have actors
pub fn Initialize(app_state: *AppState, renderer: ?*c.SDL_Renderer) bool {
    // setup initial actors and objects (obstacles, moving, fixed)
    // Setup breakout actor (moving paddle)
    // const paddle_one: c.SDL_FRect = .{
    //     .h = 100,
    //     .w = 20,
    //     .x = @floatFromInt(@divFloor(app_state.game_screen_width, 8)),
    //     .y = @floatFromInt(@divFloor(app_state.game_screen_height, 2) - 50),
    // };

    // _ = c.SDL_SetRenderDrawColor(renderer, 160, 170, 90, 1);
    // _ = c.SDL_RenderFillRect(renderer, &paddle_one);

    // setup grid
    // const height_cell: f32 = @floatFromInt(@divFloor(app_state.game_screen_height, GRID_DIMENSIONS[1]));
    // const width_cell: f32 = @floatFromInt(@divFloor(app_state.game_screen_width, GRID_DIMENSIONS[0]));
    // const cells_per_row: u8 = GRID_DIMENSIONS[0];

    // std.debug.print("\nGrid Dimensions: h, w {any}, {any}\n", .{ height_cell, width_cell });

    // for (GRID_MAZE, 0..) |cell, index| {
    //     if (cell == 1) {
    //         const xpos: f32 = @floatFromInt(index % cells_per_row);
    //         const ypos: f32 = @floatFromInt(@divFloor(index, cells_per_row));
    //         const grid_cell: c.SDL_FRect = .{
    //             .h = height_cell,
    //             .w = width_cell,
    //             .x = width_cell * xpos,
    //             .y = height_cell * ypos,
    //         };

    //         std.debug.print("Grid cell to paint: i,j = {d},{d}, x, y = {d}, {}\n", .{ xpos, ypos, width_cell * xpos, height_cell * ypos });
    //         _ = c.SDL_SetRenderDrawColor(renderer, 255, 255, 255, 1);
    //         _ = c.SDL_RenderRect(renderer, &grid_cell);
    //         // _ = c.SDL_SetRenderDrawColor(renderer, 160, 170, 90, 1);
    //         // _ = c.SDL_RenderFillRect(renderer, &grid_cell);
    //     }
    // }
    //
    render_maze(&GRID_MAZE, GRID_DIMENSIONS, app_state, renderer);

    return true;
}

pub fn PlayBreakoutLoopIteration() void {}
