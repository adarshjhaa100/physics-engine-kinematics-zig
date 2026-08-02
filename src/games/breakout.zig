const AppState = @import("../type_schema.zig").AppState;
const c = @import("../main.zig").c;

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
