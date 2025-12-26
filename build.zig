const std = @import("std");

// Although this function looks imperative, it does not perform the build
// directly and instead it mutates the build graph (`b`) that will be then
// executed by an external runner. The functions in `std.Build` implement a DSL
// for defining build steps and express dependencies between them, allowing the
// build runner to parallelize the build automatically (and the cache system to
// know when a step doesn't need to be re-run).
pub fn build(b: *std.Build) void {
    // Standard target options allow the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});
    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});
    // It's also possible to define more custom flags to toggle optional features
    // of this build script using `b.option()`. All defined flags (including
    // target and optimize options) will be listed when running `zig build --help`
    // in this directory.

    const raylib_dep = b.dependency("raylib_zig", .{
        .target = target,
        .optimize = optimize,
    });

    const raylib = raylib_dep.module("raylib"); // main raylib module
    const raygui = raylib_dep.module("raygui"); // raygui module
    const raylib_artifact = raylib_dep.artifact("raylib"); // raylib C library

    // Here we define an executable. An executable needs to have a root module
    // which needs to expose a `main` function. While we could add a main function
    // to the module defined above, it's sometimes preferable to split business
    // logic and the CLI into two separate modules.
    //
    // If your goal is to create a Zig library for others to use, consider if
    // it might benefit from also exposing a CLI tool. A parser library for a
    // data serialization format could also bundle a CLI syntax checker, for example.
    //
    // If instead your goal is to create an executable, consider if users might
    // be interested in also being able to embed the core functionality of your
    // program in their own executable in order to avoid the overhead involved in
    // subprocessing your CLI tool.
    //
    // If neither case applies to you, feel free to delete the declaration you
    // don't need and to put everything under a single module.
    const exe = b.addExecutable(.{
        .name = "CHIP8-Emu",
        .root_module = b.createModule(.{
            // b.createModule defines a new module just like b.addModule but,
            // unlike b.addModule, it does not expose the module to consumers of
            // this package, which is why in this case we don't have to give it a name.
            .root_source_file = b.path("src/main.zig"),
            // Target and optimization levels must be explicitly wired in when
            // defining an executable or library (in the root module), and you
            // can also hardcode a specific target for an executable or library
            // definition if desireable (e.g. firmware for embedded devices).
            .target = target,
            .optimize = optimize,
            // List of modules available for import in source files part of the
            // root module.
            .imports = &.{
                // Here "Zig" is the name you will use in your source code to
                // import this module (e.g. `@import("Zig")`). The name is
                // repeated because you are allowed to rename your imports, which
                // can be extremely useful in case of collisions (which can happen
                // importing modules from different packages).
                .{ .name = "raylib", .module = raylib },
                .{ .name = "raygui", .module = raygui },
            },
        }),
    });

    const options = b.addOptions();
    // Load all roms at compile-time.
    // Add the amazing chip8 test suite roms from: https://github.com/Timendus/chip8-test-suite
    options.addOption([7][]const u8, "test_roms", .{
        @embedFile("chip8-test-suite/bin/1-chip8-logo.ch8"),
        @embedFile("chip8-test-suite/bin/2-ibm-logo.ch8"),
        @embedFile("chip8-test-suite/bin/3-corax+.ch8"),
        @embedFile("chip8-test-suite/bin/4-flags.ch8"),
        @embedFile("chip8-test-suite/bin/5-quirks.ch8"),
        @embedFile("chip8-test-suite/bin/6-keypad.ch8"),
        @embedFile("chip8-test-suite/bin/7-beep.ch8"),
    });
    options.addOption([7][:0]const u8, "test_rom_names", .{
        "chip8-test-suite/bin/1-chip8-logo.ch8",
        "chip8-test-suite/bin/2-ibm-logo.ch8",
        "chip8-test-suite/bin/3-corax+.ch8",
        "chip8-test-suite/bin/4-flags.ch8",
        "chip8-test-suite/bin/5-quirks.ch8",
        "chip8-test-suite/bin/6-keypad.ch8",
        "chip8-test-suite/bin/7-beep.ch8",
    });

    // Add the chip8 demo roms from: https://github.com/kripod/chip8-roms
    options.addOption([7][]const u8, "demo_roms", .{
        @embedFile("chip8-roms/demos/Maze (alt) [David Winter, 199x].ch8"),
        @embedFile("chip8-roms/demos/Maze [David Winter, 199x].ch8"),
        @embedFile("chip8-roms/demos/Particle Demo [zeroZshadow, 2008].ch8"),
        @embedFile("chip8-roms/demos/Sierpinski [Sergey Naydenov, 2010].ch8"),
        @embedFile("chip8-roms/demos/Stars [Sergey Naydenov, 2010].ch8"),
        @embedFile("chip8-roms/demos/Trip8 Demo (2008) [Revival Studios].ch8"),
        @embedFile("chip8-roms/demos/Zero Demo [zeroZshadow, 2007].ch8"),
    });
    options.addOption([7][:0]const u8, "demo_rom_names", .{
        "chip8-roms/demos/Maze (alt) [David Winter, 199x].ch8",
        "chip8-roms/demos/Maze [David Winter, 199x].ch8",
        "chip8-roms/demos/Particle Demo [zeroZshadow, 2008].ch8",
        "chip8-roms/demos/Sierpinski [Sergey Naydenov, 2010].ch8",
        "chip8-roms/demos/Stars [Sergey Naydenov, 2010].ch8",
        "chip8-roms/demos/Trip8 Demo (2008) [Revival Studios].ch8",
        "chip8-roms/demos/Zero Demo [zeroZshadow, 2007].ch8",
    });

    // Also include the text files for displaying to the user the controls etc before they play a game.
    options.addOption([68][]const u8, "game_roms", .{
        @embedFile("chip8-roms/games/Astro Dodge [Revival Studios, 2008].ch8"),
        @embedFile("chip8-roms/games/15 Puzzle [Roger Ivie].ch8"),
        @embedFile("chip8-roms/games/Airplane.ch8"),
        @embedFile("chip8-roms/games/Blitz [David Winter].ch8"),
        @embedFile("chip8-roms/games/Bowling [Gooitzen van der Wal].ch8"),
        @embedFile("chip8-roms/games/Breakout (Brix hack) [David Winter, 1997].ch8"),
        @embedFile("chip8-roms/games/Breakout [Carmelo Cortez, 1979].ch8"),
        @embedFile("chip8-roms/games/Brick (Brix hack, 1990).ch8"),
        @embedFile("chip8-roms/games/Brix [Andreas Gustafsson, 1990].ch8"),
        @embedFile("chip8-roms/games/Cave.ch8"),
        @embedFile("chip8-roms/games/Coin Flipping [Carmelo Cortez, 1978].ch8"),
        @embedFile("chip8-roms/games/Connect 4 [David Winter].ch8"),
        @embedFile("chip8-roms/games/Craps [Camerlo Cortez, 1978].ch8"),
        @embedFile("chip8-roms/games/Figures.ch8"),
        @embedFile("chip8-roms/games/Filter.ch8"),
        @embedFile("chip8-roms/games/Guess [David Winter] (alt).ch8"),
        @embedFile("chip8-roms/games/Guess [David Winter].ch8"),
        @embedFile("chip8-roms/games/Hi-Lo [Jef Winsor, 1978].ch8"),
        @embedFile("chip8-roms/games/Hidden [David Winter, 1996].ch8"),
        @embedFile("chip8-roms/games/Kaleidoscope [Joseph Weisbecker, 1978].ch8"),
        @embedFile("chip8-roms/games/Landing.ch8"),
        @embedFile("chip8-roms/games/Lunar Lander (Udo Pernisz, 1979).ch8"),
        @embedFile("chip8-roms/games/Mastermind FourRow (Robert Lindley, 1978).ch8"),
        @embedFile("chip8-roms/games/Merlin [David Winter].ch8"),
        @embedFile("chip8-roms/games/Missile [David Winter].ch8"),
        @embedFile("chip8-roms/games/Most Dangerous Game [Peter Maruhnic].ch8"),
        @embedFile("chip8-roms/games/Nim [Carmelo Cortez, 1978].ch8"),
        @embedFile("chip8-roms/games/Paddles.ch8"),
        @embedFile("chip8-roms/games/Pong (1 player).ch8"),
        @embedFile("chip8-roms/games/Pong (alt).ch8"),
        @embedFile("chip8-roms/games/Pong [Paul Vervalin, 1990].ch8"),
        @embedFile("chip8-roms/games/Pong 2 (Pong hack) [David Winter, 1997].ch8"),
        @embedFile("chip8-roms/games/Programmable Spacefighters [Jef Winsor].ch8"),
        @embedFile("chip8-roms/games/Puzzle.ch8"),
        @embedFile("chip8-roms/games/Reversi [Philip Baltzer].ch8"),
        @embedFile("chip8-roms/games/Rocket [Joseph Weisbecker, 1978].ch8"),
        @embedFile("chip8-roms/games/Rocket Launch [Jonas Lindstedt].ch8"),
        @embedFile("chip8-roms/games/Rocket Launcher.ch8"),
        @embedFile("chip8-roms/games/Rush Hour [Hap, 2006] (alt).ch8"),
        @embedFile("chip8-roms/games/Rush Hour [Hap, 2006].ch8"),
        @embedFile("chip8-roms/games/Russian Roulette [Carmelo Cortez, 1978].ch8"),
        @embedFile("chip8-roms/games/Sequence Shoot [Joyce Weisbecker].ch8"),
        @embedFile("chip8-roms/games/Shooting Stars [Philip Baltzer, 1978].ch8"),
        @embedFile("chip8-roms/games/Slide [Joyce Weisbecker].ch8"),
        @embedFile("chip8-roms/games/Soccer.ch8"),
        @embedFile("chip8-roms/games/Space Flight.ch8"),
        @embedFile("chip8-roms/games/Space Intercept [Joseph Weisbecker, 1978].ch8"),
        @embedFile("chip8-roms/games/Space Invaders [David Winter] (alt).ch8"),
        @embedFile("chip8-roms/games/Space Invaders [David Winter].ch8"),
        @embedFile("chip8-roms/games/Spooky Spot [Joseph Weisbecker, 1978].ch8"),
        @embedFile("chip8-roms/games/Squash [David Winter].ch8"),
        @embedFile("chip8-roms/games/Submarine [Carmelo Cortez, 1978].ch8"),
        @embedFile("chip8-roms/games/Sum Fun [Joyce Weisbecker].ch8"),
        @embedFile("chip8-roms/games/Syzygy [Roy Trevino, 1990].ch8"),
        @embedFile("chip8-roms/games/Tank.ch8"),
        @embedFile("chip8-roms/games/Tapeworm [JDR, 1999].ch8"),
        @embedFile("chip8-roms/games/Tetris [Fran Dachille, 1991].ch8"),
        @embedFile("chip8-roms/games/Tic-Tac-Toe [David Winter].ch8"),
        @embedFile("chip8-roms/games/Timebomb.ch8"),
        @embedFile("chip8-roms/games/Tron.ch8"),
        @embedFile("chip8-roms/games/UFO [Lutz V, 1992].ch8"),
        @embedFile("chip8-roms/games/Vers [JMN, 1991].ch8"),
        @embedFile("chip8-roms/games/Vertical Brix [Paul Robson, 1996].ch8"),
        @embedFile("chip8-roms/games/Wall [David Winter].ch8"),
        @embedFile("chip8-roms/games/Wipe Off [Joseph Weisbecker].ch8"),
        @embedFile("chip8-roms/games/Worm V4 [RB-Revival Studios, 2007].ch8"),
        @embedFile("chip8-roms/games/X-Mirror.ch8"),
        @embedFile("chip8-roms/games/ZeroPong [zeroZshadow, 2007].ch8"),
    });

    options.addOption([68][:0]const u8, "game_rom_names", .{
        "Astro Dodge [Revival Studios, 2008]",
        "15 Puzzle [Roger Ivie]",
        "Airplane",
        "Blitz [David Winter]",
        "Bowling [Gooitzen van der Wal]",
        "Breakout (Brix hack) [David Winter, 1997]",
        "Breakout [Carmelo Cortez, 1979]",
        "Brick (Brix hack, 1990)",
        "Brix [Andreas Gustafsson, 1990]",
        "Cave",
        "Coin Flipping [Carmelo Cortez, 1978]",
        "Connect 4 [David Winter]",
        "Craps [Camerlo Cortez, 1978]",
        "Figures",
        "Filter",
        "Guess [David Winter] (alt)",
        "Guess [David Winter]",
        "Hi-Lo [Jef Winsor, 1978]",
        "Hidden [David Winter, 1996]",
        "Kaleidoscope [Joseph Weisbecker, 1978]",
        "Landing",
        "Lunar Lander (Udo Pernisz, 1979)",
        "Mastermind FourRow (Robert Lindley, 1978)",
        "Merlin [David Winter]",
        "Missile [David Winter]",
        "Most Dangerous Game [Peter Maruhnic]",
        "Nim [Carmelo Cortez, 1978]",
        "Paddles",
        "Pong (1 player)",
        "Pong (alt)",
        "Pong [Paul Vervalin, 1990]",
        "Pong 2 (Pong hack) [David Winter, 1997]",
        "Programmable Spacefighters [Jef Winsor]",
        "Puzzle",
        "Reversi [Philip Baltzer]",
        "Rocket [Joseph Weisbecker, 1978]",
        "Rocket Launch [Jonas Lindstedt]",
        "Rocket Launcher",
        "Rush Hour [Hap, 2006] (alt)",
        "Rush Hour [Hap, 2006]",
        "Russian Roulette [Carmelo Cortez, 1978]",
        "Sequence Shoot [Joyce Weisbecker]",
        "Shooting Stars [Philip Baltzer, 1978]",
        "Slide [Joyce Weisbecker]",
        "Soccer",
        "Space Flight",
        "Space Intercept [Joseph Weisbecker, 1978]",
        "Space Invaders [David Winter] (alt)",
        "Space Invaders [David Winter]",
        "Spooky Spot [Joseph Weisbecker, 1978]",
        "Squash [David Winter]",
        "Submarine [Carmelo Cortez, 1978]",
        "Sum Fun [Joyce Weisbecker]",
        "Syzygy [Roy Trevino, 1990]",
        "Tank",
        "Tapeworm [JDR, 1999]",
        "Tetris [Fran Dachille, 1991]",
        "Tic-Tac-Toe [David Winter]",
        "Timebomb",
        "Tron",
        "UFO [Lutz V, 1992]",
        "Vers [JMN, 1991]",
        "Vertical Brix [Paul Robson, 1996]",
        "Wall [David Winter]",
        "Wipe Off [Joseph Weisbecker]",
        "Worm V4 [RB-Revival Studios, 2007]",
        "X-Mirror",
        "ZeroPong [zeroZshadow, 2007]",
    });

    options.addOption([68]?[:0]const u8, "game_rom_txts", .{
        @embedFile("chip8-roms/games/Astro Dodge [Revival Studios, 2008].txt"),
        @embedFile("chip8-roms/games/15 Puzzle [Roger Ivie].txt"),
        null, // Airplane
        @embedFile("chip8-roms/games/Blitz [David Winter].txt"),
        @embedFile("chip8-roms/games/Bowling [Gooitzen van der Wal].txt"),
        @embedFile("chip8-roms/games/Breakout (Brix hack) [David Winter, 1997].txt"),
        @embedFile("chip8-roms/games/Breakout [Carmelo Cortez, 1979].txt"),
        @embedFile("chip8-roms/games/Brick (Brix hack, 1990).txt"),
        null, // Brix [Andreas Gustafsson, 1990]
        null, // Cave
        @embedFile("chip8-roms/games/Coin Flipping [Carmelo Cortez, 1978].txt"),
        @embedFile("chip8-roms/games/Connect 4 [David Winter].txt"),
        @embedFile("chip8-roms/games/Craps [Camerlo Cortez, 1978].txt"),
        null, // Figures
        null, // Filter
        @embedFile("chip8-roms/games/Guess [David Winter] (alt).txt"),
        @embedFile("chip8-roms/games/Guess [David Winter].txt"),
        @embedFile("chip8-roms/games/Hi-Lo [Jef Winsor, 1978].txt"),
        @embedFile("chip8-roms/games/Hidden [David Winter, 1996].txt"),
        @embedFile("chip8-roms/games/Kaleidoscope [Joseph Weisbecker, 1978].txt"),
        null, // Landing
        @embedFile("chip8-roms/games/Lunar Lander [Udo Pernisz, 1979].txt"),
        @embedFile("chip8-roms/games/Mastermind FourRow (Robert Lindley, 1978).txt"),
        @embedFile("chip8-roms/games/Merlin [David Winter].txt"),
        null, // Missile [David Winter]
        @embedFile("chip8-roms/games/Most Dangerous Game [Peter Maruhnic].txt"),
        @embedFile("chip8-roms/games/Nim [Carmelo Cortez, 1978].txt"),
        null, // Paddles
        null, // Pong (1 player)
        null, // Pong (alt)
        @embedFile("chip8-roms/games/Pong [Paul Vervalin, 1990].txt"),
        null, // Pong 2 (Pong hack) [David Winter, 1997]
        @embedFile("chip8-roms/games/Programmable Spacefighters [Jef Winsor].txt"),
        null, // Puzzle
        @embedFile("chip8-roms/games/Reversi [Philip Baltzer].txt"),
        null, // Rocket [Joseph Weisbecker, 1978]
        null, // Rocket Launch [Jonas Lindstedt]
        null, // Rocket Launcher
        null, // Rush Hour [Hap, 2006] (alt)
        @embedFile("chip8-roms/games/Rush Hour [Hap, 2006].txt"),
        @embedFile("chip8-roms/games/Russian Roulette [Carmelo Cortez, 1978].txt"),
        @embedFile("chip8-roms/games/Sequence Shoot [Joyce Weisbecker].txt"),
        @embedFile("chip8-roms/games/Shooting Stars [Philip Baltzer, 1978].txt"),
        @embedFile("chip8-roms/games/Slide [Joyce Weisbecker].txt"),
        null, // Soccer
        null, // Space Flight
        @embedFile("chip8-roms/games/Space Intercept [Joseph Weisbecker, 1978].txt"),
        @embedFile("chip8-roms/games/Space Invaders [David Winter] (alt).txt"),
        @embedFile("chip8-roms/games/Space Invaders [David Winter].txt"),
        @embedFile("chip8-roms/games/Spooky Spot [Joseph Weisbecker, 1978].txt"),
        null, // Squash [David Winter]
        @embedFile("chip8-roms/games/Submarine [Carmelo Cortez, 1978].txt"),
        @embedFile("chip8-roms/games/Sum Fun [Joyce Weisbecker].txt"),
        @embedFile("chip8-roms/games/Syzygy [Roy Trevino, 1990].txt"),
        @embedFile("chip8-roms/games/Tank.txt"),
        null, // Tapeworm [JDR, 1999]
        @embedFile("chip8-roms/games/Tetris [Fran Dachille, 1991].txt"),
        null, // Tic-Tac-Toe [David Winter]
        null, // Timebomb
        null, // Tron
        @embedFile("chip8-roms/games/UFO [Lutz V, 1992].txt"),
        null, // Vers [JMN, 1991]
        null, // Vertical Brix [Paul Robson, 1996]
        null, // Wall [David Winter]
        null, // Wipe Off [Joseph Weisbecker]
        @embedFile("chip8-roms/games/Worm V4 [RB-Revival Studios, 2007].txt"),
        null, // X-Mirror
        null, // ZeroPong [zeroZshadow, 2007]
    });

    exe.root_module.addOptions("build_options", options);

    exe.linkLibrary(raylib_artifact);

    // This declares intent for the executable to be installed into the
    // install prefix when running `zig build` (i.e. when executing the default
    // step). By default the install prefix is `zig-out/` but can be overridden
    // by passing `--prefix` or `-p`.
    b.installArtifact(exe);

    // This creates a top level step. Top level steps have a name and can be
    // invoked by name when running `zig build` (e.g. `zig build run`).
    // This will evaluate the `run` step rather than the default step.
    // For a top level step to actually do something, it must depend on other
    // steps (e.g. a Run step, as we will see in a moment).
    const run_step = b.step("run", "Run the app");

    // This creates a RunArtifact step in the build graph. A RunArtifact step
    // invokes an executable compiled by Zig. Steps will only be executed by the
    // runner if invoked directly by the user (in the case of top level steps)
    // or if another step depends on it, so it's up to you to define when and
    // how this Run step will be executed. In our case we want to run it when
    // the user runs `zig build run`, so we create a dependency link.
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    // By making the run step depend on the default step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
}
