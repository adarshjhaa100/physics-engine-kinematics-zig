const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // 1. Create the Module
    // We pass .link_libc = true directly in the options struct.
    const mod = b.addModule("root", .{
        .root_source_file = b.path("sdl3-intro.zig"), // replace path if required
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    // 2. Explicitly set the Include Path
    // FIRST PRINCIPLE: Path Resolution
    // We point to /usr/include so that #include <SDL3/SDL.h> resolves correctly.
    // We use .cwd_relative because this is an absolute system path, not a project path.
    mod.addIncludePath(.{ .cwd_relative = "/usr/include" });

    // 3. Explicitly set the Library Path
    // FIRST PRINCIPLE: Linker Search Paths
    // The linker needs to find libSDL3.so. Based on your previous error output,
    // your system places 64-bit libraries in /usr/lib/x86_64-linux-gnu.
    mod.addLibraryPath(.{ .cwd_relative = "/usr/lib/x86_64-linux-gnu" });

    // Fallback to /usr/lib just in case your specific setup put it there
    mod.addLibraryPath(.{ .cwd_relative = "/usr/lib" });

    // 4. Tell the linker to link against libSDL3.so
    // Note: The name must be exactly "SDL3" to match the file libSDL3.so
    mod.linkSystemLibrary("SDL3", .{});

    // 3. Create the Executable from the Module
    // The executable is now just a minimal wrapper around the module.
    const exe = b.addExecutable(.{
        .name = "sdl3_clear",
        .root_module = mod,
    });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the SDL3 Clear example");
    run_step.dependOn(&run_cmd.step);
}
