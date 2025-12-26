const rl = @import("raylib");

const ColorPalette = struct {
    pixel_on: rl.Color,
    pixel_off: rl.Color,
};

const palettes = [_]ColorPalette{
    // 0: Classic (white on black)
    .{ .pixel_on = rl.Color.white, .pixel_off = rl.Color.black },
    // 1: Green monochrome (like old CRT)
    .{ .pixel_on = rl.Color{ .r = 0, .g = 255, .b = 0, .a = 255 }, .pixel_off = rl.Color{ .r = 0, .g = 20, .b = 0, .a = 255 } },
    // 2: Amber
    .{ .pixel_on = rl.Color{ .r = 255, .g = 176, .b = 0, .a = 255 }, .pixel_off = rl.Color{ .r = 20, .g = 15, .b = 0, .a = 255 } },
    // 3: Blue
    .{ .pixel_on = rl.Color{ .r = 100, .g = 200, .b = 255, .a = 255 }, .pixel_off = rl.Color{ .r = 0, .g = 20, .b = 40, .a = 255 } },
    // 4: Purple/Pink
    .{ .pixel_on = rl.Color{ .r = 255, .g = 100, .b = 255, .a = 255 }, .pixel_off = rl.Color{ .r = 20, .g = 0, .b = 20, .a = 255 } },
    // 5: Inverted (black on white)
    .{ .pixel_on = rl.Color.black, .pixel_off = rl.Color.white },
    // 6: Game Boy (greenish)
    .{ .pixel_on = rl.Color{ .r = 15, .g = 56, .b = 15, .a = 255 }, .pixel_off = rl.Color{ .r = 155, .g = 188, .b = 15, .a = 255 } },
    // 7: Game Boy Pocket (grayscale)
    .{ .pixel_on = rl.Color{ .r = 40, .g = 40, .b = 40, .a = 255 }, .pixel_off = rl.Color{ .r = 200, .g = 200, .b = 200, .a = 255 } },
    // 8: Sepia
    .{ .pixel_on = rl.Color{ .r = 112, .g = 66, .b = 20, .a = 255 }, .pixel_off = rl.Color{ .r = 240, .g = 234, .b = 214, .a = 255 } },
    // 9: Red Alert
    .{ .pixel_on = rl.Color{ .r = 255, .g = 50, .b = 50, .a = 255 }, .pixel_off = rl.Color{ .r = 40, .g = 0, .b = 0, .a = 255 } },
    // 10: Cyan/Teal
    .{ .pixel_on = rl.Color{ .r = 0, .g = 255, .b = 255, .a = 255 }, .pixel_off = rl.Color{ .r = 0, .g = 30, .b = 30, .a = 255 } },
    // 11: Orange Glow
    .{ .pixel_on = rl.Color{ .r = 255, .g = 128, .b = 0, .a = 255 }, .pixel_off = rl.Color{ .r = 30, .g = 15, .b = 0, .a = 255 } },
    // 12: Matrix (bright green on dark green)
    .{ .pixel_on = rl.Color{ .r = 0, .g = 255, .b = 65, .a = 255 }, .pixel_off = rl.Color{ .r = 0, .g = 10, .b = 0, .a = 255 } },
    // 13: Ice Blue
    .{ .pixel_on = rl.Color{ .r = 200, .g = 240, .b = 255, .a = 255 }, .pixel_off = rl.Color{ .r = 10, .g = 30, .b = 50, .a = 255 } },
    // 14: Hot Pink
    .{ .pixel_on = rl.Color{ .r = 255, .g = 20, .b = 147, .a = 255 }, .pixel_off = rl.Color{ .r = 30, .g = 0, .b = 20, .a = 255 } },
    // 15: Yellow Highlight
    .{ .pixel_on = rl.Color{ .r = 255, .g = 255, .b = 0, .a = 255 }, .pixel_off = rl.Color{ .r = 30, .g = 30, .b = 0, .a = 255 } },
    // 16: Virtual Boy (red on dark red)
    .{ .pixel_on = rl.Color{ .r = 255, .g = 0, .b = 0, .a = 255 }, .pixel_off = rl.Color{ .r = 80, .g = 0, .b = 0, .a = 255 } },
    // 17: Neon Purple
    .{ .pixel_on = rl.Color{ .r = 191, .g = 64, .b = 191, .a = 255 }, .pixel_off = rl.Color{ .r = 20, .g = 0, .b = 30, .a = 255 } },
    // 18: Lime
    .{ .pixel_on = rl.Color{ .r = 191, .g = 255, .b = 0, .a = 255 }, .pixel_off = rl.Color{ .r = 20, .g = 30, .b = 0, .a = 255 } },
    // 19: Aqua Dream
    .{ .pixel_on = rl.Color{ .r = 127, .g = 255, .b = 212, .a = 255 }, .pixel_off = rl.Color{ .r = 0, .g = 40, .b = 30, .a = 255 } },
    // 20: Sunset Orange
    .{ .pixel_on = rl.Color{ .r = 255, .g = 99, .b = 71, .a = 255 }, .pixel_off = rl.Color{ .r = 40, .g = 10, .b = 5, .a = 255 } },
    // 21: Lavender
    .{ .pixel_on = rl.Color{ .r = 230, .g = 230, .b = 250, .a = 255 }, .pixel_off = rl.Color{ .r = 50, .g = 30, .b = 70, .a = 255 } },
    // 22: Blood Moon
    .{ .pixel_on = rl.Color{ .r = 138, .g = 7, .b = 7, .a = 255 }, .pixel_off = rl.Color{ .r = 20, .g = 5, .b = 5, .a = 255 } },
    // 23: Electric Blue
    .{ .pixel_on = rl.Color{ .r = 125, .g = 249, .b = 255, .a = 255 }, .pixel_off = rl.Color{ .r = 0, .g = 15, .b = 30, .a = 255 } },
    // 24: Forest
    .{ .pixel_on = rl.Color{ .r = 34, .g = 139, .b = 34, .a = 255 }, .pixel_off = rl.Color{ .r = 0, .g = 20, .b = 0, .a = 255 } },
    // 25: Peach
    .{ .pixel_on = rl.Color{ .r = 255, .g = 218, .b = 185, .a = 255 }, .pixel_off = rl.Color{ .r = 40, .g = 25, .b = 15, .a = 255 } },
    // 26: Midnight Blue
    .{ .pixel_on = rl.Color{ .r = 25, .g = 25, .b = 112, .a = 255 }, .pixel_off = rl.Color{ .r = 5, .g = 5, .b = 20, .a = 255 } },
    // 27: Coral
    .{ .pixel_on = rl.Color{ .r = 255, .g = 127, .b = 80, .a = 255 }, .pixel_off = rl.Color{ .r = 30, .g = 15, .b = 10, .a = 255 } },
    // 28: Gold
    .{ .pixel_on = rl.Color{ .r = 255, .g = 215, .b = 0, .a = 255 }, .pixel_off = rl.Color{ .r = 30, .g = 25, .b = 0, .a = 255 } },
    // 29: Cotton Candy
    .{ .pixel_on = rl.Color{ .r = 255, .g = 183, .b = 197, .a = 255 }, .pixel_off = rl.Color{ .r = 30, .g = 20, .b = 25, .a = 255 } },
    // 30: Mint
    .{ .pixel_on = rl.Color{ .r = 152, .g = 255, .b = 152, .a = 255 }, .pixel_off = rl.Color{ .r = 15, .g = 30, .b = 15, .a = 255 } },
};

pub fn getPaletteSize() usize {
    return palettes.len;
}

pub fn getPalette(index: usize) ColorPalette {
    return palettes[index % palettes.len];
}
