const std = @import("std");
const utils = @import("utils.zig");

const SCHEMA = @import("type_schema.zig");

const c = @cImport({
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3/SDL_main.h");
});

var window: ?*c.SDL_Window = null;
var renderer: ?*c.SDL_Renderer = null;
var prevTime: u64 = 0;

const MEMORY_POOL_SIZE: u32 = 10 * 1024;
var global_pool_buffer: [MEMORY_POOL_SIZE]u8 = undefined;
var global_fba =
    std.heap.FixedBufferAllocator.init(global_pool_buffer[0..]);
var app_processs_init: std.process.Init = undefined;

const AppState = struct {
    fba: std.heap.FixedBufferAllocator,
    game_screen_width: i32,
    game_screen_height: i32,
    game_target_fps: i32,
    game_background_color: []const u8,
    game_background_texture: []const u8,
    physics_earth_gravity: f32,
};

pub fn gameContextSetup(app_state_ptr: *AppState, init_app_state: utils.GameConfigMap) void {
    app_state_ptr.game_screen_width =
        init_app_state[@intFromEnum(utils.GameConfigKey.game_screen_width)].int;
    app_state_ptr.game_screen_height =
        init_app_state[@intFromEnum(utils.GameConfigKey.game_screen_height)].int;
    app_state_ptr.game_target_fps =
        init_app_state[@intFromEnum(utils.GameConfigKey.game_target_fps)].int;
    app_state_ptr.physics_earth_gravity =
        init_app_state[@intFromEnum(utils.GameConfigKey.physics_earth_gravity)].float;
    app_state_ptr.game_background_color =
        init_app_state[@intFromEnum(utils.GameConfigKey.game_background_color)].string[0..];
    // Use this instead of static to keep it in scope
    // Move this to separate method
    const buf_ptr =
        global_fba.allocator().alloc(u8, 1024) catch return;
    app_state_ptr.game_background_texture = init_app_state[@intFromEnum(utils.GameConfigKey.game_background_texture)].string[0..];
    app_state_ptr.fba =
        std.heap.FixedBufferAllocator.init(buf_ptr);
}

// 1. THE ZIG ENTRY POINT
// FIRST PRINCIPLE: We must satisfy Zig's runtime by providing a `pub fn main()`.
// Inside it, we immediately delegate execution to SDL3's C callback engine.
pub fn main(init: std.process.Init) void {
    // Game Init
    app_processs_init = init;
    // We pass 0 and null for argc/argv since we don't need CLI args for this example.
    _ = c.SDL_EnterAppMainCallbacks(0, null, SDL_AppInit, SDL_AppIterate, SDL_AppEvent, SDL_AppQuit);
}

// 2. INITIALIZATION CALLBACK
// FIRST PRINCIPLE: C Pointer Nullability.
// `argv` is `char *argv[]` in C. In Zig, C pointers (`[*c]`) are inherently
// nullable, so we do NOT wrap them in an optional `?`.
export fn SDL_AppInit(appstate: ?*?*anyopaque, argc: c_int, argv: [*c]?[*:0]u8) c.SDL_AppResult {
    _ = argc;
    _ = argv;

    // load init
    const config_init =
        utils.ReadConfigFile(app_processs_init, global_fba.allocator()) catch return c.SDL_APP_FAILURE;

    const init_app_state =
        global_fba.allocator().create(AppState) catch {
            std.debug.print("Failed to allocate AppState\n", .{});
            return c.SDL_APP_FAILURE;
        };
    gameContextSetup(init_app_state, config_init);

    if (appstate) |appstate_ptr| {
        // Point appstate to initialized app state
        appstate_ptr.* = @ptrCast(init_app_state);
    }

    _ = c.SDL_SetAppMetadata("Kinematics simulation engine", "1.0", "tcsc.physics.kinematics-simulation");

    prevTime = c.SDL_GetTicksNS();

    if (!c.SDL_Init(c.SDL_INIT_VIDEO)) {
        std.debug.print("Couldn't initialize SDL: {s}\n", .{c.SDL_GetError()});
        return c.SDL_APP_FAILURE;
    }

    if (!c.SDL_CreateWindowAndRenderer("tcsc/physics/kinematics-simulation", init_app_state.game_screen_width, init_app_state.game_screen_height, c.SDL_WINDOW_RESIZABLE, &window, &renderer)) {
        std.debug.print("Couldn't create window/renderer: {s}\n", .{c.SDL_GetError()});
        return c.SDL_APP_FAILURE;
    }

    // logical dimensions (actual rendering "arena" space)
    _ = c.SDL_SetRenderLogicalPresentation(renderer, init_app_state.game_screen_width, init_app_state.game_screen_height, c.SDL_LOGICAL_PRESENTATION_LETTERBOX);

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
    _ = appstate;

    // if (appstate) |validated_state| {
    //     const appState: *AppState = @ptrCast(@alignCast(validated_state));
    //     std.debug.print("\nAppstate: {d}\n", .{appState.a});
    // }

    // TIME
    // const initialTickMs = c.SDL_GetTicks();
    // const currentTick: f32 = @as(f32, @floatFromInt(initialTickMs)) / 1000.0; // time in seconds
    // std.debug.print("CurrentTick: {}\n", .{currentTick});

    // Keyboard input, key_states is snapshot of internal SDL arr
    // This has size SDL_SCANCODE_COUNT(512)
    // const key_states = c.SDL_GetKeyboardState(null);
    // for (key_states, 0..c.SDL_SCANCODE_COUNT) |_, i| {
    //     if (key_states[i]) {
    //         std.debug.print("Key {} is pressed\n", .{i});
    //     }
    // }

    // This line is necessary since this color is what SDL will use to clear and paint screen
    // Sdl render options take the last draw color set
    _ = c.SDL_SetRenderDrawColor(renderer, 20, 20, 20, c.SDL_ALPHA_OPAQUE); // black background
    _ = c.SDL_RenderClear(renderer); // Start with blank screen (above line is necessary to set blank canvas)

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
        std.debug.print("\nGame ht: {}\n", .{appState.game_screen_height});
    }
    std.debug.print("\nCurrent Allocated arena memory {d}\n", .{global_fba.end_index});

    std.debug.print("\nCWD: {any}", .{std.Io.Dir.cwd()});

    global_fba.reset(); // endIndex = 0

    _ = result;
}
