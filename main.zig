const std = @import("std");

const c = @cImport({
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3/SDL_main.h");
});

const Velocity = struct {
    vx: f32,
    vy: f32,
};

const Position = struct {
    x: f32,
    y: f32,
};

const SCREEN_HEIGHT = 600;
const SCREEN_WIDTH = 800;
var window: ?*c.SDL_Window = null;
var renderer: ?*c.SDL_Renderer = null;
var prevTime: u64 = 0;
var rectPosition: Position = .{ .x = 0, .y = 100 };

// 1. THE ZIG ENTRY POINT
// FIRST PRINCIPLE: We must satisfy Zig's runtime by providing a `pub fn main()`.
// Inside it, we immediately delegate execution to SDL3's C callback engine.
pub fn main() void {
    // We pass 0 and null for argc/argv since we don't need CLI args for this example.
    _ = c.SDL_EnterAppMainCallbacks(0, null, SDL_AppInit, SDL_AppIterate, SDL_AppEvent, SDL_AppQuit);
}

pub fn translate2DShape(initialPos: Position, v: Velocity, tick: f32) Position {
    // const finalPos: Position = .{
    //     .x = @mod((initialPosn.x + v.vx * tick), SCREEN_WIDTH - 10),
    //     .y = @mod((initialPosn.y + v.vy * tick), SCREEN_HEIGHT - 10),
    // };
    //
    std.debug.print("Velocity {}\n", .{v});
    std.debug.print("Posn {}\n", .{initialPos});

    // x2 = x1+ut (x1 is the position at the start, the above code was wrong)
    const finalPos: Position = .{
        .x = @mod((0 + v.vx * tick), SCREEN_WIDTH - 10),
        .y = @mod((100 + v.vy * tick), SCREEN_HEIGHT - 10),
    };

    // x2 = x1 + u*t
    return finalPos;
}

// 2. INITIALIZATION CALLBACK
// FIRST PRINCIPLE: C Pointer Nullability.
// `argv` is `char *argv[]` in C. In Zig, C pointers (`[*c]`) are inherently
// nullable, so we do NOT wrap them in an optional `?`.
export fn SDL_AppInit(appstate: ?*?*anyopaque, argc: c_int, argv: [*c]?[*:0]u8) c.SDL_AppResult {
    _ = appstate;
    _ = argc;
    _ = argv;

    _ = c.SDL_SetAppMetadata("Kinematics simulation engine", "1.0", "tcsc.physics.kinematics-simulation");

    prevTime = c.SDL_GetTicksNS();

    if (!c.SDL_Init(c.SDL_INIT_VIDEO)) {
        std.debug.print("Couldn't initialize SDL: {s}\n", .{c.SDL_GetError()});
        return c.SDL_APP_FAILURE;
    }

    if (!c.SDL_CreateWindowAndRenderer("tcsc/physics/kinematics-simulation", SCREEN_WIDTH, SCREEN_HEIGHT, c.SDL_WINDOW_RESIZABLE, &window, &renderer)) {
        std.debug.print("Couldn't create window/renderer: {s}\n", .{c.SDL_GetError()});
        return c.SDL_APP_FAILURE;
    }

    // logical dimensions (actual rendering "arena" space)
    _ = c.SDL_SetRenderLogicalPresentation(renderer, SCREEN_WIDTH, SCREEN_HEIGHT, c.SDL_LOGICAL_PRESENTATION_LETTERBOX);

    return c.SDL_APP_CONTINUE;
}

// 3. EVENT CALLBACK
export fn SDL_AppEvent(appstate: ?*anyopaque, event: ?*c.SDL_Event) c.SDL_AppResult {
    _ = appstate;

    // std.debug.print("EVENT: {any} /n", .{event});

    if (event) |e| {
        if (e.type == c.SDL_EVENT_QUIT) {
            return c.SDL_APP_SUCCESS;
        }
        // not printing anything. WHY?
        if (e.type == c.SDL_EVENT_KEY_DOWN) {
            std.debug.print("KEYBOARD EVENT: {any} /n", .{event});
        }
    }
    return c.SDL_APP_CONTINUE;
}

// 4. RENDER CALLBACK
export fn SDL_AppIterate(appstate: ?*anyopaque) c.SDL_AppResult {
    _ = appstate;

    var rect: c.SDL_FRect = .{};
    const vel: Velocity = .{ .vx = 100, .vy = 0 };

    // time
    const currentTick: f32 = @as(f32, @floatFromInt(c.SDL_GetTicks())) / 1000.0; // time in seconds
    std.debug.print("CurrentTick: {}\n", .{currentTick});

    _ = c.SDL_SetRenderDrawColor(renderer, 0, 0, 0, c.SDL_ALPHA_OPAQUE); // black background
    _ = c.SDL_RenderClear(renderer); // Start with blank screen (above line is necessary to set blank canvas)

    rectPosition = translate2DShape(rectPosition, vel, currentTick);

    _ = c.SDL_SetRenderDrawColor(renderer, 0, 0, 255, c.SDL_ALPHA_OPAQUE); // blue
    rect.x = rectPosition.x;
    rect.y = rectPosition.y;
    rect.w = 50;
    rect.h = 50;

    _ = c.SDL_RenderRect(renderer, &rect);

    // Finalize the render on screen
    _ = c.SDL_RenderPresent(renderer); // paint the screen

    return c.SDL_APP_CONTINUE;
}

// 5. SHUTDOWN CALLBACK
// FIRST PRINCIPLE: Explicit Return Types.
// Zig requires every function to explicitly declare its return type.
// Since this returns nothing, we must explicitly write `void`.
export fn SDL_AppQuit(appstate: ?*anyopaque, result: c.SDL_AppResult) void {
    _ = appstate;
    _ = result;
}
