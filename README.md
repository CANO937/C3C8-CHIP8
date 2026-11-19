# C3C8

A lightweight and fast **CHIP-8** interpreter/emulator written entirely in **[C3](https://c3-lang.org)**.

## Features

- Full support for all 35 standard CHIP-8 opcodes
- Scalable 64×32 monochrome display
- 60 Hz delay and sound timers
- Original 16-key hexadecimal keypad mapped to a modern QWERTY keyboard
- Zero-overhead native compilation via `c3c`

## Prerequisites

To build and run **C3C8**, you will need:

- The **[C3 compiler (`c3c`)](https://github.com)** (version 0.6 or later recommended)
- **[INSERT YOUR BACKEND LIBRARY HERE, e.g., SDL2 / Raylib / Terminal]** installed on your system

## Building & Running

Clone the repository and build the project:

```bash
git clone https://github.com
cd C3C8
c3c build
```

Run the emulator by passing the path to a CHIP-8 ROM:

```bash
./build/c3c8 path/to/rom.ch8
```

*(Alternatively, you can build and run directly using: `c3c run -- path/to/rom.ch8`)*

## Controls

The original CHIP-8 hexadecimal keypad is mapped to the left side of a standard QWERTY keyboard:

| CHIP-8 Keypad | Keyboard |
| :---: | :---: |
| `1` `2` `3` `C` | `1` `2` `3` `4` |
| `4` `5` `6` `D` | `Q` `W` `E` `R` |
| `7` `8` `9` `E` | `A` `S` `D` `F` |
| `A` `0` `B` `F` | `Z` `X` `C` `V` |

- **ESC**: Quit the emulator

## Project Structure

```text
C3C8/
├── src/
│   ├── main.c3      # Entry point, main loop, and video/input handling
│   ├── chip8.c3     # CPU, 4KB memory, registers, stack, and opcode execution
│   └── ...
├── roms/            # Suggested directory for your .ch8 ROMs
├── project.json     # C3 project configuration
└── README.md
```

## Useful Resources

If you need test ROMs to verify emulation accuracy, check out:
- [Timendus CHIP-8 Test Suite](https://github.com)
- [Cowgod's CHIP-8 Technical Reference](http://free.fr)

## License

Distributed under the **MIT License**. See `LICENSE` for more information.
