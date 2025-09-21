# Bootfire

Bootfire is a tiny experiment that brings the legendary DOOM fire effect into the very first 512 bytes of your computer.
No operating system. No libraries. Just raw 16-bit assembly, VGA mode 13h, and a hand-rolled palette.

A boot sector demo you can actually hack and extend.

## Features
- Fits entirely in a single boot sector (512 bytes).
- Pure x86 real mode assembly, written for [FASM](https://flatassembler.net/)
- Runs in *VGA 320×200×256* color mode (mode 13h).
- Custom palette: black → deep red → orange → yellow → white-hot.
- Implements the classic DOOM fire algorithm in bare metal.
- Works on real hardware and in emulators like QEMU/Bochs/VirtualBox.

## Why
Bootfire is designed to show how much you can do with almost nothing:
    - Direct access to VGA memory.
    - Palette tricks for color ramps.
    - Fire propagation algorithm in tight loops.
    - The art of making beauty in impossible size limits.

Perfect opportunity for tinkering graphics, and demo-scene minimalism.

## Build & Run
Requirements:
    - [FASM](https://flatassembler.net/)
    - [QEMU](https://www.qemu.org/)

```sh
./run.sh
```

This assembles `src/bootfire.asm`, creates a bootable floppy image, and launches QEMU.
To debug with GDB:
```sh
./run.sh --gdb
```

## Project Layout
```sh
bootfire/
  ├─ src/
  │   ├─ bootfire.asm      # main 512B fire effect
  │   └─ palette.inc       # generated fire gradient (db r,g,b)
  ├─ tools/
  │   └─ gen_palette.py    # palette generator script
  ├─ docs/
  │   └─ design.md         # notes on algorithm, memory map
  ├─ run.sh                # assemble, build image, run in QEMU
```

## Learn More
- Original DOOM fire algorithm inspiration: simple, fast, and mesmerizing.
- VGA mode 13h: 320×200 with linear framebuffer, perfect for demos.
- Demo scene culture: doing the impossible in 512 bytes.

## Acknowledgements
- [Fabien Sanglard - How DOOM fire was done](https://fabiensanglard.net/doom_fire_psx/)
- [FASM docs](https://flatassembler.net/docs.php)

## License
[MIT](./LICENSE)
