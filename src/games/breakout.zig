const AppState = @import("../type_schema.zig").AppState;
const c = @import("../main.zig").c;

pub const GRID_DIMENSIONS: [2]u8 = [_]u8{ 8, 6 };
// Flattened array in
pub const GRID_MAZE = [_]u8{ 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1 };

///Setup grid in matrix format with obstacles and path.
/// Have actors
pub fn Initialize(app_state: *AppState, renderer: ?*c.SDL_Renderer) bool {
    // setup initial actors and objects (obstacles, moving, fixed)
    // Setup breakout actor (moving paddle)
    const paddle_one: c.SDL_FRect = .{
        .h = 100,
        .w = 20,
        .x = @floatFromInt(@divFloor(app_state.game_screen_width, 8)),
        .y = @floatFromInt(@divFloor(app_state.game_screen_height, 2) - 50),
    };

    _ = c.SDL_SetRenderDrawColor(renderer, 160, 170, 90, 1);
    _ = c.SDL_RenderFillRect(renderer, &paddle_one);

    return true;
}

pub fn PlayBreakoutLoopIteration() void {}
