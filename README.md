# Zig CHIP-8 Emulator

This is an implementation of the original CHIP-8 interpreter, this project was also weekend project for me to discover and learn Zig while also having some fun with low-level code.

The emulator allows you to load any user-specified `.ch8` rom using the -f parameter! Otherwise you can play a set of built-in games, demos and tests using the -g, -d and -t parameters respectively.

Use the -h argument for help with the command line:

```
CHIP-8 Emulator, created by Narvin Chana (GitHub: Narvin-Chana)

The CHIP-8 emulator contains 7 demos, 7 tests and quite a few different games built-in. 
You can find more info here for demos and games: https://github.com/kripod/chip8-roms
The tests were sourced from here: https://github.com/Timendus/chip8-test-suite

Here are the mutually exclusive arguments the application accepts:
 - "-f/-F": Will load the .ch8 file from the specified path.
 - "-d/-D": Will run the emulator's built-in demos. (default)
 - "-t/-T": Will run the emulator's built-in tests.
 - "-g/-G": Will run the emulator's built-in games, some games come with rule explanations, others to be figured out on the fly. If a game has explanations, I've added them to be displayed before starting the game (and logged to the terminal). Press the space-bar to skip explanations and see the game.

Optional arguments:
 - "-a/-A": Will use an AZERTY keyboard configuration instead of the default QWERTY layout.
 - "-y/-Y": For a quick history lesson on the CHIP-8 console!

No matter the mode chosen, pressing space-bar will move to the next ROM in the same category (or reset the ROM if you used -f/-F)!
Press P to randomize the color palette! Changing the rom with space-bar will also randomize the color palette.

The original CHIP-8's controller had the following keys: 
[ 1 2 3 C ]                    [ 1 2 3 4 ]
[ 4 5 6 D ] Which is mapped to [ Q W E R ]
[ 7 8 9 E ]  your keyboard as: [ A S D F ]
[ A 0 B F ]                    [ Z X C V ]

AZERTY users can change the application to the AZERTY layout by using the -a argument!
```

All prebuilt ROMs are built-in to the emulator's executable, meaning the emulator's .exe can be redistributed without any dependencies.

## Building from source

Clone the project recursively with git (the project uses git submodules for compile-time dependencies) and run `zig build -Doptimize=ReleaseSmall install run`.

Command line arguments can be added by adding "--" to the end of the zig command, eg: `zig build -Doptimize=ReleaseSmall install run -- -f myCustomRom.ch8`.