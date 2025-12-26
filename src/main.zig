const std = @import("std");
const rl = @import("raylib");
const build_options = @import("build_options");

const chip8 = @import("chip8.zig");
const color_palette = @import("color_palette.zig");
const ia = @import("input_accumulator.zig");

fn roundUp(a: u32, b: u32) u32 {
    return std.math.ceil(a / @as(f32, b)) * b;
}

const EmulatorMode = enum {
    // "-f or -F"
    CustomROM,
    // "-d or -D"
    Demos,
    // "-t or -T"
    Tests,
    // "-g or -G"
    Games,
};

const CmdLineArgs = struct {
    emulator_mode: EmulatorMode = EmulatorMode.Demos,
    rom_file_path: ?[:0]u8 = null,
    is_azerty: bool = false,

    fn init(allocator: std.mem.Allocator) !CmdLineArgs {
        var cmdLineArgs: CmdLineArgs = .{};

        var args = try std.process.argsWithAllocator(allocator);
        defer args.deinit();

        // Skip the exe name.
        _ = args.next();

        while (args.next()) |arg| {
            if (arg[0] != '-') {
                std.log.err("Unrecognized argument: {s}.", .{arg});
                return error.UnrecognizedArg;
            }
            switch (arg[1]) {
                'h', 'H' => {
                    logHelp();
                    return error.HelpArg;
                },
                'y', 'Y' => {
                    logHistory();
                    return error.HistoryNerd;
                },
                'f', 'F' => {
                    cmdLineArgs.emulator_mode = EmulatorMode.CustomROM;
                    const n = args.next();
                    if (n == null) {
                        std.log.err("-f / -F argument was not followed with a filepath...", .{});
                        return error.MissingCustomRomFilePath;
                    }
                    cmdLineArgs.rom_file_path = try allocator.dupeZ(u8, n.?);
                },
                'd', 'D' => cmdLineArgs.emulator_mode = EmulatorMode.Demos,
                't', 'T' => cmdLineArgs.emulator_mode = EmulatorMode.Tests,
                'g', 'G' => cmdLineArgs.emulator_mode = EmulatorMode.Games,
                'a', 'A' => cmdLineArgs.is_azerty = true,
                else => {
                    std.log.err("Unrecognized argument: {s}.\nUse -h for help!", .{arg});
                    return error.UnrecognizedArg;
                },
            }
        }
        return cmdLineArgs;
    }

    fn logHistory() void {
        std.log.info(
            \\ History of the CHIP-8 console (sourced from https://tobiasvl.github.io):
            \\ -------------------------------------------------------------------------
            \\ CHIP-8 was created by RCA engineer Joe Weisbecker in 1977 for the COSMAC VIP microcomputer. It was intended as a simpler way to make small programs and games for the computer. Instead of using machine language for the VIP's CDP1802 processor, you could type in hexadecimal instructions (with the VIP's hex keypad) that resembled machine code, but which were more high-level, and interpreted on the fly by a small program (the CHIP-8 emulator/interpreter).
            \\
            \\ CHIP-8 soon spread to other computers, like the Finnish Telmac 1800, the Australian DREAM 6800, ETI-660 and MicroBee, and the Canadian ACE VDU.
            \\ 
            \\ By 1984 the interest in CHIP-8 petered out. However, in 1990 it had a renaissance on the HP48 graphing calculators with CHIP-48 and the now-famous SUPER-CHIP extension with higher resolution.
        , .{});
    }

    fn logHelp() void {
        std.log.info(
            \\ CHIP-8 Emulator, created by Narvin Chana (GitHub: Narvin-Chana)
            \\ The CHIP-8 emulator contains 7 demos, 7 tests and quite a few different games built-in. 
            \\ You can find more info here for demos and games: https://github.com/kripod/chip8-roms
            \\ The tests were sourced from here: https://github.com/Timendus/chip8-test-suite
            \\
            \\ Here are the mutually exclusive arguments the application accepts:
            \\  - "-f FILEPATH/-F FILEPATH": Will load the .ch8 file from the provided filepath.
            \\  - "-d/-D": Will run the emulator's built-in demos. (default)
            \\  - "-t/-T": Will run the emulator's built-in tests.
            \\  - "-g/-G": Will run the emulator's built-in games, some games come with rule explanations, others to be figured out on the fly. If a game has explanations, I've added them to be displayed before starting the game (and logged to the terminal). Press the space-bar to skip explanations and see the game.
            \\ 
            \\ Optional arguments:
            \\  - "-a/-A": Will use an AZERTY keyboard configuration instead of the default QWERTY layout.
            \\  - "-y/-Y": For a quick history lesson on the CHIP-8 console!
            \\
            \\ No matter the mode chosen, pressing space-bar will move to the next ROM in the same category (or reset the ROM if you used -f/-F)!
            \\ Press P to randomize the color palette! Changing the rom with space-bar will also randomize the color palette.
            \\
            \\ The original CHIP-8's controller had the following keys: 
            \\ [ 1 2 3 C ]                    [ 1 2 3 4 ]
            \\ [ 4 5 6 D ] Which is mapped to [ Q W E R ]
            \\ [ 7 8 9 E ]  your keyboard as: [ A S D F ]
            \\ [ A 0 B F ]                    [ Z X C V ]
            \\ 
            \\ AZERTY users can change the application to the AZERTY layout by using the -a argument!
        , .{});
    }
};

fn getRandomPalette(rnd: std.Random) usize {
    return std.Random.intRangeAtMost(rnd, usize, 0, color_palette.getPaletteSize() - 1);
}

fn shouldDoGameExplanation(rom_descriptions: ?[]const ?[:0]const u8, current_rom: usize) bool {
    return rom_descriptions != null and rom_descriptions.?[current_rom] != null;
}

pub fn main() !void {
    var seed: u64 = undefined;
    try std.posix.getrandom(std.mem.asBytes(&seed));
    var rnd = std.Random.DefaultPrng.init(seed);

    // Create GPA for IO purposes.
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    // Read command line args.
    const args: CmdLineArgs = CmdLineArgs.init(gpa.allocator()) catch std.process.exit(0);
    defer {
        if (args.rom_file_path != null) gpa.allocator().free(args.rom_file_path.?);
    }
    var input_accumulator = ia.InputAccumulator.init(args.is_azerty);

    var custom_rom_data: [1][]u8 = undefined;
    if (args.emulator_mode == EmulatorMode.CustomROM) {
        // Load custom rom.
        std.log.info("Loading ROM from file: {s}", .{args.rom_file_path.?});
        custom_rom_data[0] = try std.fs.cwd().readFileAlloc(gpa.allocator(), args.rom_file_path.?, chip8.max_rom_size);
    }
    defer {
        if (args.emulator_mode == EmulatorMode.CustomROM) {
            gpa.allocator().free(custom_rom_data[0]);
        }
    }

    const custom_rom_names: [1][:0]const u8 = .{if (args.rom_file_path != null) args.rom_file_path.? else ""};

    // Obtain the roms we will use (imported at compile-time in build.zig).
    const roms = switch (args.emulator_mode) {
        EmulatorMode.CustomROM => &custom_rom_data,
        EmulatorMode.Demos => &build_options.demo_roms,
        EmulatorMode.Tests => &build_options.test_roms,
        EmulatorMode.Games => &build_options.game_roms,
    };
    const rom_names = switch (args.emulator_mode) {
        EmulatorMode.CustomROM => &custom_rom_names,
        EmulatorMode.Demos => &build_options.demo_rom_names,
        EmulatorMode.Tests => &build_options.test_rom_names,
        EmulatorMode.Games => &build_options.game_rom_names,
    };
    const rom_descriptions: ?[]const ?[:0]const u8 = switch (args.emulator_mode) {
        EmulatorMode.Games => &build_options.game_rom_txts,
        else => null,
    };
    const rom_count: usize = roms.len;
    var current_rom: usize = 0;
    var current_palette: usize = getRandomPalette(rnd.random());

    try chip8.init(roms[current_rom]);
    defer chip8.deinit();

    const screen_width = comptime roundUp(800, chip8.display_width);
    const screen_height = comptime roundUp(450, chip8.display_height);

    rl.initWindow(screen_width, screen_height, "CHIP-8 Emulator");
    defer rl.closeWindow();

    var is_in_game_explanation: bool = shouldDoGameExplanation(rom_descriptions, current_rom);
    if (is_in_game_explanation and (rom_descriptions != null) and (rom_descriptions.?[current_rom] != null)) {
        std.log.info("{s}\n", .{rom_descriptions.?[current_rom].?});
    }

    while (!rl.windowShouldClose()) {
        // Update logic
        var pressed_space = rl.isKeyPressed(rl.KeyboardKey.space);

        // Check if we should render the emulator.
        var update_emulator = true;
        if (is_in_game_explanation) {
            update_emulator = false;
            if (pressed_space) {
                is_in_game_explanation = false;
                // Avoid skipping the rom.
                pressed_space = false;
            }
        }

        // See if we want to swap to the next rom.
        if (pressed_space) {
            current_rom = (current_rom + 1) % rom_count;
            chip8.deinit();
            try chip8.init(roms[current_rom]);
            current_palette = getRandomPalette(rnd.random());
            is_in_game_explanation = shouldDoGameExplanation(rom_descriptions, current_rom);
            if (is_in_game_explanation and (rom_descriptions != null) and (rom_descriptions.?[current_rom] != null)) {
                std.log.info("{s}\n", .{rom_descriptions.?[current_rom].?});
            }
        }

        if (update_emulator) {
            chip8.update(rl.getFrameTime(), rnd.random(), &input_accumulator);
        }

        // Check if we want to randomize the palette
        if (rl.isKeyPressed(rl.KeyboardKey.p)) {
            current_palette = getRandomPalette(rnd.random());
        }

        //----------------------------------------------------------------------------------
        // Draw
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(.black);

        if (update_emulator) {
            const palette = color_palette.getPalette(current_palette);
            const pixel_off = palette.pixel_off;
            const pixel_on = palette.pixel_on;
            const pixel_scale_x = screen_width / chip8.display_width;
            const pixel_scale_y = screen_height / chip8.display_height;

            for (chip8.state.display, 0..) |row, y| {
                for (row, 0..) |is_on, x| {
                    const color = if (is_on) pixel_on else pixel_off;
                    rl.drawRectangle(@intCast(x * pixel_scale_x), @intCast(y * pixel_scale_y), pixel_scale_x, pixel_scale_y, color);
                }
            }
            rl.drawText(rom_names[current_rom], 10, screen_height - 15, 14, rl.Color.red);
        } else if (is_in_game_explanation and (rom_descriptions != null) and (rom_descriptions.?[current_rom] != null)) {
            rl.drawText(rom_names[current_rom], 10, 15, 24, rl.Color.red);
            rl.drawText("Game explanations were logged to the terminal.\nPress space-bar to start playing.", 75, 135, 30, rl.Color.white);
        }
    }
}
