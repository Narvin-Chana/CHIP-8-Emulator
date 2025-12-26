const std = @import("std");
const rl = @import("raylib");

pub const InputAccumulator = struct {
    keysDown: [16]bool,
    keysReleased: [16]bool,
    is_azerty: bool = false,

    pub fn init(new_is_azerty: bool) InputAccumulator {
        return .{
            .keysDown = std.mem.zeroes([16]bool),
            .keysReleased = std.mem.zeroes([16]bool),
            .is_azerty = new_is_azerty,
        };
    }

    pub fn update(this: *InputAccumulator) void {
        for (0..16) |val| {
            const key = this.convertInputToKey(@as(u4, @truncate(val)));
            this.keysDown[val] = rl.isKeyDown(key);
            this.keysReleased[val] = rl.isKeyReleased(key);
        }
    }

    pub fn reset(this: *InputAccumulator) void {
        this.keysDown = std.mem.zeroes([16]bool);
        this.keysReleased = std.mem.zeroes([16]bool);
    }

    pub fn isKeyDown(this: *const InputAccumulator, key: u4) bool {
        return this.keysDown[key];
    }

    pub fn isKeyReleased(this: *const InputAccumulator, key: u4) bool {
        return this.keysReleased[key];
    }

    pub fn dump(this: *const InputAccumulator) void {
        std.debug.print("Pressed:\n", .{});
        for (this.keysDown, 0..) |b, i| {
            std.debug.print("{X}: {}\n", .{ i, b });
        }
        std.debug.print("Released:\n", .{});
        for (this.keysReleased, 0..) |b, i| {
            std.debug.print("{X}: {}\n", .{ i, b });
        }
    }

    fn convertInputToKey(this: *const InputAccumulator, key: u4) rl.KeyboardKey {
        switch (key) {
            0x1 => return rl.KeyboardKey.one,
            0x2 => return rl.KeyboardKey.two,
            0x3 => return rl.KeyboardKey.three,
            0xC => return rl.KeyboardKey.four,

            0x4 => return if (!this.is_azerty) rl.KeyboardKey.q else rl.KeyboardKey.a,
            0x5 => return if (!this.is_azerty) rl.KeyboardKey.w else rl.KeyboardKey.z,
            0x6 => return rl.KeyboardKey.e,
            0xD => return rl.KeyboardKey.r,

            0x7 => return if (!this.is_azerty) rl.KeyboardKey.a else rl.KeyboardKey.q,
            0x8 => return rl.KeyboardKey.s,
            0x9 => return rl.KeyboardKey.d,
            0xE => return rl.KeyboardKey.f,

            0xA => return if (!this.is_azerty) rl.KeyboardKey.z else rl.KeyboardKey.w,
            0x0 => return rl.KeyboardKey.x,
            0xB => return rl.KeyboardKey.c,
            0xF => return rl.KeyboardKey.v,
        }
    }
};
