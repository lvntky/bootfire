# Resources

A curated set of resources ive used while writing a 512-byte Doom Fire demo in real-mode assembly.

---

## Core Effect (Algorithm & Palettes)
- [How DOOM fire was done — Fabien Sanglard](https://fabiensanglard.net/doom_fire_psx/)  
  Classic article explaining the algorithm, buffer layout, and palette logic.
- [Rust Implementation of the Doom Fire FX — Notryanb](https://notryanb.github.io/rust-doom-fire-fx.html)  
  Step-by-step implementation in Rust, good for cross-checking propagation.
- [Simple Implementation of Fire Effects a la Doom (Python)](https://github.com/wkrzemien/DoomFire)  
  Small, clean codebase to compare with your own.

---

## VGA Mode 13h & Palette/DAC
- [Mode 13h — Wikipedia](https://en.wikipedia.org/wiki/Mode_13h)  
  Quick reference: 320×200, 256 colors, linear framebuffer at `A000:0000`.
- [VGA Hardware — OSDev Wiki](https://wiki.osdev.org/VGA_Hardware)  
  Reference for VGA registers, DAC ports (`3C8h`, `3C9h`), and video memory.
- [FreeVGA Project — osdever.net](https://www.osdever.net/FreeVGA/home.htm)  
  Deep dive into VGA/SVGA hardware programming.

---

## VSync / Tearing Control
- [VGA Input Status #1 Register (port 3DAh)](https://wiki.osdev.org/VGA_Hardware#Input_Status_Registers)  
  How to poll vertical retrace for smoother blitting.

---

## BIOS Services
- [Ralf Brown’s Interrupt List (RBIL)](http://www.ctyme.com/rbrown.htm)  
  Definitive list of BIOS interrupts, including `INT 10h` (video) and `INT 13h` (disk).

---

## Assembler & Build
- [Flat Assembler (FASM) Documentation](https://flatassembler.net/docs.php)  
  Official manual for FASM (syntax, macros, `repeat`, `times`, etc.).

---

## Emulators & Debugging
- [Bochs Debugger](https://bochs.sourceforge.io/doc/docbook/user/internal-debugger.html)  
  Built-in debugger for step-by-step execution in real mode.
- [QEMU GDB Stub Documentation](https://wiki.qemu.org/Documentation/Networking#GDB)  
  How to attach GDB (`-s -S`) to debug bootloaders.

---

## Minimal Checklist
1. **Set video mode 13h**: `mov ax, 0x0013 ; int 0x10`.  
2. **Program DAC**:  
   - `out 3C8h, al` (set start index).  
   - Stream `R,G,B` bytes (0..63) to `3C9h`.  
3. **Fire buffer**: 320×200 intensities.  
   - Bottom row = fuel (random or constant).  
   - Propagate upward using neighbor average − decay.  
4. **Each frame**:  
   - Optional **VSync wait** on port `3DAh`.  
   - Blit buffer indices to VRAM at `A000:0000`.

---

## Assembly sources
https://www.felixcloutier.com/x86/stos:stosb:stosw:stosd:stosq