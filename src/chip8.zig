const std = @import("std");
const rl = @import("raylib");
const stack_module = @import("stack.zig");

// CHIP-8 uses 12 bit addresses.
const Address = u12;
// CHIP-8 uses 16 bit instructions.
const Instruction = u16;

pub const display_width = 64;
pub const display_height = 32;

const memory_byte_size = 4096;
// Font data (one sprite per hex character).
const font_data = [_]u8{
    0xF0, 0x90, 0x90, 0x90, 0xF0, // 0
    0x20, 0x60, 0x20, 0x20, 0x70, // 1
    0xF0, 0x10, 0xF0, 0x80, 0xF0, // 2
    0xF0, 0x10, 0xF0, 0x10, 0xF0, // 3
    0x90, 0x90, 0xF0, 0x10, 0x10, // 4
    0xF0, 0x80, 0xF0, 0x10, 0xF0, // 5
    0xF0, 0x80, 0xF0, 0x90, 0xF0, // 6
    0xF0, 0x10, 0x20, 0x40, 0x40, // 7
    0xF0, 0x90, 0xF0, 0x90, 0xF0, // 8
    0xF0, 0x90, 0xF0, 0x10, 0xF0, // 9
    0xF0, 0x90, 0xF0, 0x90, 0x90, // A
    0xE0, 0x90, 0xE0, 0x90, 0xE0, // B
    0xF0, 0x80, 0x80, 0x80, 0xF0, // C
    0xE0, 0x90, 0x90, 0x90, 0xE0, // D
    0xF0, 0x80, 0xF0, 0x80, 0xF0, // E
    0xF0, 0x80, 0xF0, 0x80, 0x80, // F
};
const font_character_size = @as(comptime_int, font_data.len * @typeInfo(u8).int.bits / 8 / 16);

pub const max_rom_size = memory_byte_size - State.rom_offset;

// Number of elements the CHIP-8 stack can contain.
const stack_size = 16;

// CPU frequency (in Hz)
const cpu_frequency = 700;
const time_to_cpu_tick = @as(f32, 1.0) / cpu_frequency;
var cpu_clock: f32 = 0.0;

// Timer frequency (in Hz)
const timer_frequency = 60;
const time_to_timer_tick = @as(f32, 1.0) / timer_frequency;
var timer_clock: f32 = 0.0;

const State = struct {
    // RAM
    // [0x000, 0x1FF] is system reserved space
    // [0x200, 0xFFF] is for the user rom
    memory: [memory_byte_size]u8,

    // Current display, wiped at the start of every new frame
    display: [display_height][display_width]bool,

    // Registers
    program_counter: Address = rom_offset,
    index_register: Address = rom_offset,
    delay_timer: u8 = 0,
    sound_timer: u8 = 0,
    variable_registers: [16]u8 = std.mem.zeroes([16]u8),

    const font_offset = 0x050;
    const rom_offset = 0x200;

    pub fn init() State {
        var s: State = comptime .{ .memory = undefined, .display = undefined };
        for (font_data, 0..) |val, i| {
            s.memory[font_offset + i] = val;
        }
        return s;
    }
    pub fn clearDisplay(this: *State) void {
        this.display = comptime std.mem.zeroes([display_height][display_width]bool);
    }
    pub fn dump(this: *const State) void {
        std.debug.dumpHex(&this.memory);
        std.debug.print("Program Counter: 0x{X:0>2}\n", .{this.program_counter});
        std.debug.print("Index Register: 0x{X:0>2}\n", .{this.index_register});
    }
};

pub const default_state: State = State.init();
pub var state: State = undefined;

const Stack = stack_module.stack(Address, stack_size);
pub var stack: Stack = undefined;

pub fn init(rom: []const u8) !void {
    // Validate ROM size
    if (rom.len > max_rom_size) {
        return error.RomTooLarge;
    }

    // Wipe memory and copy in the default_state.
    state = default_state;

    // Copy in ROM data.
    @memcpy(state.memory[0x200..][0..rom.len], rom);

    // Start with a zeroed-out display.
    state.clearDisplay();

    try stack.init();
}

pub fn deinit() void {
    stack.deinit();
}

pub fn update(delta_time: f32, rnd: std.Random) void {
    // Update timers (they are independant of the instruction tick cycle)
    timer_clock += delta_time;
    while (timer_clock > time_to_timer_tick) {
        if (state.delay_timer != 0) state.delay_timer = state.delay_timer - 1;
        if (state.sound_timer != 0) state.sound_timer = state.sound_timer - 1;
        timer_clock = @max(timer_clock - time_to_timer_tick, 0);
    }

    // Update CPU
    cpu_clock += delta_time;
    while (cpu_clock > time_to_cpu_tick) {
        // Fetch instruction to execute from memory (two bytes which are pointed to by the PC)
        const instruction: Instruction = std.mem.readInt(Instruction, state.memory[state.program_counter..][0..2], std.builtin.Endian.big);
        // std.debug.print("Instruction: 0x{X:0>4}\n", .{instruction});

        // Increment the program counter.
        incrementPC();

        // Decode and execute instruction.
        decodeAndExecute(instruction, rnd);

        cpu_clock = @max(cpu_clock - time_to_cpu_tick, 0);
    }
}

fn getBit(n: u3, num: u8) bool {
    return ((num >> n) & 1) != 0;
}

fn incrementPC() void {
    // Allow overflow to match original chip8 hw.
    state.program_counter +%= 2;
}

fn decrementPC() void {
    // Allow overflow to match original chip8 hw.
    state.program_counter -%= 2;
}

pub var is_azerty: bool = false;

fn convertInputToKey(key: u4) rl.KeyboardKey {
    switch (key) {
        0x1 => return rl.KeyboardKey.one,
        0x2 => return rl.KeyboardKey.two,
        0x3 => return rl.KeyboardKey.three,
        0xC => return rl.KeyboardKey.four,

        0x4 => return if (!is_azerty) rl.KeyboardKey.q else rl.KeyboardKey.a,
        0x5 => return if (!is_azerty) rl.KeyboardKey.w else rl.KeyboardKey.z,
        0x6 => return rl.KeyboardKey.e,
        0xD => return rl.KeyboardKey.r,

        0x7 => return if (!is_azerty) rl.KeyboardKey.a else rl.KeyboardKey.q,
        0x8 => return rl.KeyboardKey.s,
        0x9 => return rl.KeyboardKey.d,
        0xE => return rl.KeyboardKey.f,

        0xA => return if (!is_azerty) rl.KeyboardKey.z else rl.KeyboardKey.w,
        0x0 => return rl.KeyboardKey.x,
        0xB => return rl.KeyboardKey.c,
        0xF => return rl.KeyboardKey.v,
    }
}

fn isKeyDown(key: u4) bool {
    return rl.isKeyDown(convertInputToKey(key));
}

fn isKeyReleased(key: u4) bool {
    return rl.isKeyReleased(convertInputToKey(key));
}

fn decodeAndExecute(instruction: Instruction, rnd: std.Random) void {
    const op = @as(u4, @truncate(instruction >> 12));
    const x = @as(u4, @truncate(instruction >> 8));
    const y = @as(u4, @truncate(instruction >> 4));
    const n = @as(u4, @truncate(instruction));
    const nn = @as(u8, @truncate(instruction));
    const nnn = @as(u12, @truncate(instruction));

    const vx = state.variable_registers[x];
    const vy = state.variable_registers[y];

    // std.debug.print("op: 0x{X}, n: 0x{X:0>1}, nn: 0x{X:0>2}, nnn: 0x{X:0>3}\n", .{ op, n, nn, nnn });

    switch (op) {
        0x0 => switch (nn) {
            // 00E0: Clear
            0xE0 => state.clearDisplay(),
            // 00EE: Return
            0xEE => {
                if (stack.pop()) |adr| {
                    state.program_counter = adr;
                } else {
                    executionError(ExecutionError.EmptyStack, instruction);
                }
            },
            else => executionError(ExecutionError.UnsupportedInstruction, instruction),
        },
        // 1NNN: Jump
        0x1 => state.program_counter = nnn,
        // 2NNN: Call
        0x2 => {
            // Push current pc to stack.
            if (stack.push(state.program_counter)) {} else |err| {
                executionError(err, instruction);
            }
            state.program_counter = nnn;
        },
        // 3XNN: Skip conditional if vx and nn equal
        0x3 => if (vx == nn) incrementPC(),
        // 4XNN: Skip conditional if vx and nn not equal
        0x4 => if (vx != nn) incrementPC(),
        0x5 => switch (n) {
            // 5XY0: Skip conditional if vx and vy equal
            0x0 => if (vx == vy) incrementPC(),
            else => executionError(ExecutionError.UnsupportedInstruction, instruction),
        },
        // 6XNN: Set register
        0x6 => state.variable_registers[x] = nn,
        // 7XNN: Add value to register
        0x7 => state.variable_registers[x] +%= nn,
        0x8 => switch (n) {
            // 8XY0: Set vx to vy
            0x0 => state.variable_registers[x] = vy,
            // 8XY1: Set vx to (vx OR vy)
            0x1 => {
                state.variable_registers[x] = vx | vy;
                state.variable_registers[0xF] = 0;
            },
            // 8XY2: Set vx to (vx AND vy)
            0x2 => {
                state.variable_registers[x] = vx & vy;
                state.variable_registers[0xF] = 0;
            },
            // 8XY3: Set vx to (vx XOR vy)
            0x3 => {
                state.variable_registers[x] = vx ^ vy;
                state.variable_registers[0xF] = 0;
            },
            // 8XY4: Set vx to (vx + vy)
            0x4 => {
                state.variable_registers[x] +%= vy;
                // Overflow detection is written to vf
                state.variable_registers[0xF] = @intFromBool(vx > std.math.maxInt(u8) - vy);
            },
            // 8XY5: Set vx to (vx - vy)
            0x5 => {
                state.variable_registers[x] -%= vy;
                // Overflow detection is written to vf (0 if overflow, 1 if none)
                state.variable_registers[0xF] = @intFromBool(vx >= vy);
            },
            // 8XY6: Set vx to (vy >> 1)
            0x6 => {
                state.variable_registers[x] = vy >> 1;
                // Set 0xF to the least-significant bit pre-shift.
                state.variable_registers[0xF] = vy & 1;
            },
            // 8XY7: Set vx to (vy - vx)
            0x7 => {
                state.variable_registers[x] = vy -% vx;
                // Overflow detection is written to vf (0 if overflow, 1 if none)
                state.variable_registers[0xF] = @intFromBool(vy >= vx);
            },
            // 8XYE: Set vx to (vy << 1)
            0xE => {
                state.variable_registers[x] = vy << 1;
                // Set 0xF to the most-significant bit pre-shift.
                state.variable_registers[0xF] = vy >> 7;
            },
            else => executionError(ExecutionError.UnsupportedInstruction, instruction),
        },
        0x9 => switch (n) {
            // 9XY0: Skip conditional if vx and vy not equal
            0x0 => if (vx != vy) incrementPC(),
            else => executionError(ExecutionError.UnsupportedInstruction, instruction),
        },
        // ANNN: Set index register to nnn
        0xA => state.index_register = nnn,
        // BNNN: Jump to nnn with offset v0
        0xB => state.program_counter = nnn + state.variable_registers[0x0],
        // CXNN: Set vx to to (rand & nn)
        0xC => state.variable_registers[x] = std.Random.int(rnd, u8) & nn,
        // DXYN: Display
        0xD => {
            var y_coord = vy % display_height;
            state.variable_registers[0xF] = 0;
            for (0..n) |i| {
                var x_coord = vx % display_width;
                const sprite_data = state.memory[state.index_register + i];
                for (0..8) |j| {
                    // Clip at right edge
                    if (x_coord >= display_width) break;
                    // We iterate on sprite data from MSB to LSB.
                    const sprite_bit = getBit(@as(u3, @truncate(7 - j)), sprite_data);
                    // We have to write to the VF register when a collision occurs.
                    if (sprite_bit and state.display[y_coord][x_coord]) {
                        state.variable_registers[0xF] = 1;
                    }
                    // Sprite drawring is a XOR between the sprite_bit and the display pixel.
                    state.display[y_coord][x_coord] ^= sprite_bit;
                    x_coord += 1;
                }

                if (y_coord + 1 == display_height) {
                    break;
                }
                y_coord += 1;
            }
        },
        0xE => switch (nn) {
            // EX9E: Skip if key pressed
            0x9E => if (isKeyDown(@as(u4, @truncate(vx)))) incrementPC(),
            // EXA1: Skip if key not pressed
            0xA1 => if (!isKeyDown(@as(u4, @truncate(vx)))) incrementPC(),
            else => executionError(ExecutionError.UnsupportedInstruction, instruction),
        },
        0xF => switch (nn) {
            // FX07: Set vx to the delay timer
            0x07 => state.variable_registers[x] = state.delay_timer,
            // FX0A: Block and wait for input
            0x0A => {
                for (0..16) |key| {
                    if (isKeyReleased(@as(u4, @truncate(key)))) {
                        state.variable_registers[x] = @as(u8, @truncate(key));
                        return;
                    }
                }
                // If no key was pressed we repeat this instruction to stall until an input arrives.
                decrementPC();
            },
            // FX15: Set the delay timer to vx
            0x15 => state.delay_timer = vx,
            // FX18: Set the sound timer to vx
            0x18 => state.sound_timer = vx,
            // FX1E: Add vx to index register
            0x1E => {
                // Detection if address exceeds the typical addressing range (0x0FFF)
                if (state.index_register + vx > 0x0FFF) state.variable_registers[0xF] = 1;
                state.index_register +%= vx;
            },
            // FX29: Set index register to the font character that represents vx
            0x29 => state.index_register = State.font_offset + (vx & 0xF) * font_character_size,
            // FX33: Binary-coded decimal conversion
            0x33 => {
                // Extract the digits of vx in decimal form
                // Eg: for 0x9C, or 156, we'd want to extract 6, 5 and 1.
                const digit_2 = vx / 100;
                const digit_1 = (vx / 10) % 10;
                const digit_0 = vx % 10;
                state.memory[state.index_register] = digit_2;
                state.memory[state.index_register + 1] = digit_1;
                state.memory[state.index_register + 2] = digit_0;
            },
            // FX55: Register store
            0x55 => for (0..(1 + @as(u8, x))) |i| {
                state.memory[state.index_register + i] = state.variable_registers[@as(u4, @truncate(i))];
            },
            // FX65: Register load
            0x65 => for (0..(1 + @as(u8, x))) |i| {
                state.variable_registers[@as(u4, @truncate(i))] = state.memory[state.index_register + i];
            },
            else => executionError(ExecutionError.UnsupportedInstruction, instruction),
        },
    }
}

const ExecutionError = error{
    UnsupportedInstruction,
    EmptyStack,
};

fn executionError(err: anyerror, instruction: Instruction) void {
    std.log.err("Error {} occurred when executing instruction: 0x{X:0>4}", .{ err, instruction });
    std.debug.panic("", .{});
}
