const std = @import("std");

const SCHEMA = @import("type_schema.zig");

const c = @cImport({
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3/SDL_main.h");
});

const SCREEN_HEIGHT = 600;
const SCREEN_WIDTH = 800;
var window: ?*c.SDL_Window = null;
var renderer: ?*c.SDL_Renderer = null;
var prevTime: u64 = 0;
const ACCL_G = 9.8;
const TARGET_FPS = 60;
const INITIAL_POS: SCHEMA.Position = .{ .x = 0, .y = SCREEN_HEIGHT - 50 };
var rectPosition: SCHEMA.Position = INITIAL_POS;
var global_arena_allocator = std.heap.ArenaAllocator.init(std.heap.page_allocator); // this should be here and deinit in local

const AppState = struct {
    a: i32,
    b: i32,
    fba: std.heap.FixedBufferAllocator,
};

// 1. THE ZIG ENTRY POINT
// FIRST PRINCIPLE: We must satisfy Zig's runtime by providing a `pub fn main()`.
// Inside it, we immediately delegate execution to SDL3's C callback engine.
pub fn main() void {
    // We pass 0 and null for argc/argv since we don't need CLI args for this example.
    _ = c.SDL_EnterAppMainCallbacks(0, null, SDL_AppInit, SDL_AppIterate, SDL_AppEvent, SDL_AppQuit);
}

pub fn translate2DShape(initialPos: SCHEMA.Position, vInit: SCHEMA.Velocity, a: SCHEMA.Velocity, tick: f32) SCHEMA.Position {
    std.debug.print("Posn {}\n", .{initialPos});
    std.debug.print("Current Velocity vx={}, vy={}\n", .{ vInit.vx + a.vx * tick, vInit.vy + a.vy * tick });

    // allocate text using default allocator and get a slice to it
    // This is runtime now!
    // const textStats = std.fmt.allocPrint(allocator, "\nPosn {}\n", .{initialPos}) catch "Error";
    // defer allocator.free(textStats);
    // std.debug.print("Len {}\n", .{textStats.len});

    // render Text
    // Use this to scale text - SDL_SetRenderScale(renderer, 4.0f, 4.0f);
    _ = c.SDL_SetRenderScale(renderer, 1, 1);
    _ = c.SDL_SetRenderDrawColor(renderer, 220, 220, 220, c.SDL_ALPHA_OPAQUE);

    // _ = c.SDL_RenderDebugText(renderer, SCREEN_WIDTH - @as(f32, @floatFromInt(textStats.len * 8)), 10, textStats.ptr);
    // x2 = x1+ut (x1 is the position at the start, the abov    e code was wrong)
    const finalPos: SCHEMA.Position = .{
        .x = @mod((INITIAL_POS.x + vInit.vx * tick + a.vx * tick * tick / 2), SCREEN_WIDTH - 10),
        .y = @mod((INITIAL_POS.y + vInit.vy * tick + a.vy * tick * tick / 2), SCREEN_HEIGHT - 10),
    };

    // x2 = x1 + u*t
    return finalPos;
}

// 2. INITIALIZATION CALLBACK
// FIRST PRINCIPLE: C Pointer Nullability.
// `argv` is `char *argv[]` in C. In Zig, C pointers (`[*c]`) are inherently
// nullable, so we do NOT wrap them in an optional `?`.
export fn SDL_AppInit(appstate: ?*?*anyopaque, argc: c_int, argv: [*c]?[*:0]u8) c.SDL_AppResult {
    _ = argc;
    _ = argv;

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator); // this needs to be here and deinit later ig

    const init_app_state =
        arena.allocator().create(AppState) catch {
            std.debug.print("Failed to allocate AppState\n", .{});
            return c.SDL_APP_FAILURE;
        };

    // Use this instead of static to keep it in scope
    const buf_ptr = arena.allocator().alloc(u8, 1024) catch return c.SDL_APP_FAILURE;

    init_app_state.a = 12;
    init_app_state.b = 23;
    init_app_state.fba = std.heap.FixedBufferAllocator.init(buf_ptr);

    if (appstate) |appstate_ptr| {
        appstate_ptr.* = @ptrCast(init_app_state);
    }
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

    _ = c.SDL_SetRenderVSync(renderer, 1);

    return c.SDL_APP_CONTINUE;
}

// 3. EVENT CALLBACK
export fn SDL_AppEvent(appstate: ?*anyopaque, event: ?*c.SDL_Event) c.SDL_AppResult {
    _ = appstate;
    // TODO: link renderer and other init parameters inside a Struct and make appstate point to that

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
    // _ = appstate;

    if (appstate) |validated_state| {
        const appState: *AppState = @ptrCast(@alignCast(validated_state));
        std.debug.print("\nAppstate: {d}\n", .{appState.a});
    }

    // TIME
    const initialTickMs = c.SDL_GetTicks();
    const currentTick: f32 = @as(f32, @floatFromInt(initialTickMs)) / 1000.0; // time in seconds
    std.debug.print("CurrentTick: {}\n", .{currentTick});

    // Keyboard input, key_states is snapshot of internal SDL arr
    // This has size SDL_SCANCODE_COUNT(512)
    const key_states = c.SDL_GetKeyboardState(null);
    for (key_states, 0..c.SDL_SCANCODE_COUNT) |_, i| {
        if (key_states[i]) {
            std.debug.print("Key {} is pressed\n", .{i});
        }
    }

    // Load Sprite
    // c.SDL_LoadPNG(file: [*c]const u8)

    // This line is necessary since this color is what SDL will use to clear and paint screen
    // Sdl render options take the last draw color set
    _ = c.SDL_SetRenderDrawColor(renderer, 20, 20, 20, c.SDL_ALPHA_OPAQUE); // black background
    _ = c.SDL_RenderClear(renderer); // Start with blank screen (above line is necessary to set blank canvas)

    var rect: c.SDL_FRect = .{};
    const vel: SCHEMA.Velocity = .{ .vx = 20, .vy = -20 };
    const acc: SCHEMA.Velocity = .{ .vx = 10, .vy = -3 + ACCL_G };

    rectPosition = translate2DShape(rectPosition, vel, acc, currentTick);
    _ = c.SDL_SetRenderScale(renderer, 1.0, 1.0);
    _ = c.SDL_SetRenderDrawColor(renderer, 0, 0, 220, c.SDL_ALPHA_OPAQUE); // blue
    rect.x = rectPosition.x;
    rect.y = rectPosition.y;
    rect.w = 50;
    rect.h = 50;

    _ = c.SDL_RenderRect(renderer, &rect);

    // Finalize the render on screen
    _ = c.SDL_RenderPresent(renderer); // paint the screen

    // delta for FPS to catch up
    // const elapsedDeltaTick = c.SDL_GetTicks() - initialTickMs;
    // if (elapsedDeltaTick > THRESHOLD) {
    //     c.SDL_Sleep
    // }
    return c.SDL_APP_CONTINUE;
}

// 5. SHUTDOWN CALLBACK
// FIRST PRINCIPLE: Explicit Return Types.
// Zig requires every function to explicitly declare its return type.
// Since this returns nothing, we must explicitly write `void`.
export fn SDL_AppQuit(appstate: ?*anyopaque, result: c.SDL_AppResult) void {
    if (appstate) |appstate_ptr| {
        const appState: *AppState = @ptrCast(@alignCast(appstate_ptr));
        std.debug.print("\nDeallocate: {}\n", .{appState.a});
    }
    std.debug.print("\nCurrent Allocated arena memory {x}\n", .{global_arena_allocator.queryCapacity()});

    global_arena_allocator.deinit();

    _ = result;
}
