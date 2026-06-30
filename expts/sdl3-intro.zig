const std = @import("std");

const c = @cImport({
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3/SDL_main.h");
});

var window: ?*c.SDL_Window = null;
var renderer: ?*c.SDL_Renderer = null;
var prevTime: u64 = 0;

// 1. THE ZIG ENTRY POINT
// FIRST PRINCIPLE: We must satisfy Zig's runtime by providing a `pub fn main()`.
// Inside it, we immediately delegate execution to SDL3's C callback engine.
pub fn main() void {
    // We pass 0 and null for argc/argv since we don't need CLI args for this example.
    _ = c.SDL_EnterAppMainCallbacks(0, null, SDL_AppInit, SDL_AppIterate, SDL_AppEvent, SDL_AppQuit);
}

// pub fn getCurrentTime() i96 {
//     var threaded_io: std.Io.Threaded = .init_single_threaded;
//     const io = threaded_io.io();
//     defer threaded_io.deinit();

//     return std.Io.Clock.now(.awake, io).toNanoseconds();
// }

// 2. INITIALIZATION CALLBACK
// FIRST PRINCIPLE: C Pointer Nullability.
// `argv` is `char *argv[]` in C. In Zig, C pointers (`[*c]`) are inherently
// nullable, so we do NOT wrap them in an optional `?`.
export fn SDL_AppInit(appstate: ?*?*anyopaque, argc: c_int, argv: [*c]?[*:0]u8) c.SDL_AppResult {
    _ = appstate;
    _ = argc;
    _ = argv;

    _ = c.SDL_SetAppMetadata("Example Renderer Clear", "1.0", "com.example.renderer-clear");

    prevTime = c.SDL_GetTicksNS();

    if (!c.SDL_Init(c.SDL_INIT_VIDEO)) {
        std.debug.print("Couldn't initialize SDL: {s}\n", .{c.SDL_GetError()});
        return c.SDL_APP_FAILURE;
    }

    if (!c.SDL_CreateWindowAndRenderer("examples/renderer/clear", 640, 480, c.SDL_WINDOW_RESIZABLE, &window, &renderer)) {
        std.debug.print("Couldn't create window/renderer: {s}\n", .{c.SDL_GetError()});
        return c.SDL_APP_FAILURE;
    }

    _ = c.SDL_SetRenderLogicalPresentation(renderer, 800, 600, c.SDL_LOGICAL_PRESENTATION_LETTERBOX);

    return c.SDL_APP_CONTINUE;
}

// 3. EVENT CALLBACK
export fn SDL_AppEvent(appstate: ?*anyopaque, event: ?*c.SDL_Event) c.SDL_AppResult {
    _ = appstate;

    std.debug.print("EVENT: {any} /n", .{event});

    if (event) |e| {
        if (e.type == c.SDL_EVENT_QUIT) {
            return c.SDL_APP_SUCCESS;
        }
    }
    return c.SDL_APP_CONTINUE;
}

// 4. RENDER CALLBACK
export fn SDL_AppIterate(appstate: ?*anyopaque) c.SDL_AppResult {
    _ = appstate;
    const currentTime = c.SDL_GetTicksNS();
    const elapsed = currentTime - prevTime;
    prevTime = currentTime;
    std.debug.print("Latency: {}ns \n", .{elapsed});
    std.debug.print("FPS: {any} \n", .{std.math.divCeil(u64, std.math.pow(u64, 10, 9), elapsed)});

    const now: f64 = @as(f64, @floatFromInt(c.SDL_GetTicks())) / 1000.0;

    const red: f32 = @floatCast(0.5 + 0.5 * c.SDL_sin(now));
    const green: f32 = @floatCast(0.5 + 0.5 * c.SDL_sin(now + c.SDL_PI_D * 2.0 / 3.0));
    const blue: f32 = @floatCast(0.5 + 0.5 * c.SDL_sin(now + c.SDL_PI_D * 4.0 / 3.0));

    _ = c.SDL_SetRenderDrawColorFloat(renderer, red, green, blue, c.SDL_ALPHA_OPAQUE_FLOAT);

    _ = c.SDL_RenderClear(renderer);
    _ = c.SDL_RenderPresent(renderer);

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
