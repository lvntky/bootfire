# Bootfire — Design Document

Version: 0.1.0  
Target: x86 BIOS, single-stage **512-byte** boot sector, real mode, **Mode 13h (320×200×256)**

---

## 1) Goals

- Show a classic **Doom fire** effect directly from a **boot sector** (no OS).
- Keep it readable: small, well-labeled sections; minimal macros; no external libs.
- Fit in **one sector (512 bytes)** including the **0xAA55** signature.
- Run in emulators (**Bochs**, **QEMU**) and likely on real hardware.

Non-goals (for first cut):
- Protected mode / long mode
- Disk loading beyond LBA 0 (no second stage)
- Sound, input beyond exit key

---

## 2) Environment & Constraints

- **Real mode** (16-bit), BIOS already loads sector to **0000:7C00** and jumps there.
- **Video**: Mode 13h (320×200×8bpp), linear framebuffer at **A000:0000**.
- **Palette DAC**: ports **3C8h** (index) and **3C9h** (data), 6-bit RGB (0..63).
- **Memory**: we must not clobber IVT (0000:0000), BDA (0040:0000), EBDA (~9FC00).
- **Stack**: Set `SS:SP` to a safe high segment (e.g., `7000:FFFE`).
- **Size limit**: 510 bytes payload + 2 bytes boot signature.

---

## 3) Memory Layout

```
0000:0000  IVT
0040:0000  BDA
...
07C0:0000  BIOS loads boot sector at 0000:7C00 (linear 0x7C00)
7000:FFFE  Stack top (grows down)
A000:0000  VRAM (64 KiB window for Mode 13h)
```

- **Fire buffer**: Use **VRAM directly** (indices), *or* a small shadow buffer if you want clean reads/writes. For 512-byte budget, write **directly to A000** and read from below lines.

---

## 4) File Layout

- `boot.asm` — single source (FASM/NASM).  
- `palette.inc` — optional palette table (R,G,B bytes 0..63).  
- `design.md` — this file.  
- `Makefile` / simple build script (optional).

---

## 5) Modules & Responsibilities

1. **Startup**
   - Set stack (`SS:SP`).
   - `DS := CS` (so data labels work).
   - `int 10h, AX=0013h` set Mode 13h.

2. **Palette**
   - Install palette:
     - `out 3C8h, 0` → start at index 0.
     - Stream `R,G,B` bytes to `3C9h`.
   - Options:
     - **Procedural** palette (tiny, recommended for 512B).
     - **Table-based** via `include 'palette.inc'` (costs bytes).

3. **Fire Buffer Initialization**
   - Clear screen buffer (indices).
   - Seed bottom row as **fuel** (constant high value or random).

4. **Propagation (per frame)**
   - For each pixel above bottom:
     ```
     idx = y*W + x
     src = idx + W + rand_offset(0..3)   ; sample from below
     new = max(0, buffer[src] - decay(0..1))
     store new at idx
     ```
   - Write result directly into **VRAM** (A000), so display is automatic.

5. **VSync (optional)**
   - Poll **3DAh** Input Status #1 to wait for vertical retrace to reduce tearing.

6. **Exit Key (optional)**
   - Poll `int 16h, AH=01h` (keystroke available). If ESC pressed, hang/reset.

---

## 6) Algorithm Details

- **Resolution**: `W=320`, `H=200`.
- **Fire intensity range**: Traditionally **0..36**. You can scale to **0..255** if palette supports it.
- **Bottom row fuel**:
  - Option A: Set to max intensity every frame.
  - Option B: Random speckle for flicker (tiny LCG).

- **Propagation Rule (classic)**:
  ```
  buffer[y*W + x] =
      max(0, buffer[(y+1)*W + x + rand(-1..1)] - (rand(0..1)))
  ```
  (In 16-bit, use only nonnegative offsets to keep code tiny: `+rand(0..3)` and handle wrap by masking.)

- **Palette**: Map intensity to RGB (0..63). Fire gradient: black → deep red → orange → yellow → white.

---

## 7) Data & Registers (Conventions)

- **Registers**:
  - `ES:DI` → VRAM write pointer (A000:0000 + offset)
  - `DS:SI` → data (palette, optional)
  - `AX,BX,CX,DX` → scratch
- **Segments**:
  - `DS = CS` (after `push cs / pop ds`)
  - `ES = A000h` for blits

- **Ports**:
  - `3C8h` (write index)
  - `3C9h` (write RGB triplets)
  - `3DAh` (read status; bit3 = vertical retrace)

---

## 8) Size Budget (Target)

| Component                | Bytes (approx) |
|--------------------------|----------------|
| Set stack / mode         | 20–30          |
| Procedural palette       | 70–120         |
| Init fuel line           | 15–30          |
| Propagation core (tight) | 120–180        |
| Optional vsync           | 10–20          |
| Optional key exit        | 20–30          |
| Boot sig + padding       | 2 (+padding)   |
| **Total**                | **≤ 512**      |

> If over budget: remove vsync, use constant fuel (no RNG), shrink decay logic, or switch to a shorter palette.

---

## 9) Pseudocode (Frame Loop)

```
setup_stack()
video_mode_13h()
install_palette()

seed_bottom_row()

while true:
  propagate_fire_one_frame()
  (optional) vsync_wait()
  (optional) if key_pressed(ESC): break

hang()
```

**Propagation (intensity indices):**
```
for y in (H-2) down to 0:
  for x in 0..W-1:
    src = (y+1)*W + (x + rand2()) & (W-1)   ; keep inside line
    val = buffer[src] - (rand1())
    if val < 0: val = 0
    buffer[y*W + x] = val
```

---

## 10) RNG (Tiny)

- **1-byte LCG**:
  ```
  seed = seed*a + c      ; 8-bit wrap
  rand1 = seed & 1
  rand2 = seed & 3
  ```
  Choose `a=205`, `c=251` (both odd). This is compact and “random enough”.

---

## 11) VSync Wait (Optional)

- Poll **3DAh** until retrace starts, then ends:
  ```
  wait_not_retrace:
    in al, 3DAh
    test al, 08h
    jnz wait_not_retrace

  wait_retrace:
    in al, 3DAh
    test al, 08h
    jz  wait_retrace
  ```

---

## 12) Input (Optional ESC)

- Check key available (`int 16h, AH=01h`).
- If available, read via `AH=00h`. If `AL=27` (ESC), exit/hang.

---

## 13) Build & Run

- **Assemble (FASM)**:
  ```
  fasm boot.asm boot.bin
  ```

- **Run (QEMU)**:
  ```
  qemu-system-i386 -fda boot.bin
  ```

- **Run (Bochs)**: Create a simple config with `floppya: 1_44=boot.bin, status=inserted`
  and enable the internal debugger if needed.

- **Write to USB/IMG** (danger: be careful with device path):
  ```
  dd if=boot.bin of=/dev/sdX bs=512 count=1 conv=notrunc
  ```

---

## 14) Testing Strategy

- **Smoke test**: Mode changes, colors appear, no crash.
- **Palette test**: Fill VRAM with `0..255` repeating; verify gradient matches palette.
- **Fire test**: Fuel line lit; propagation visible; no memory corruption (no snow/tearing).
- **Performance**: Should be easily full-speed in emulators.

---

## 15) Debugging Tips

- **Bochs** internal debugger: single-step, inspect memory at `A000:0000`.
- **Magic breakpoint**: `xchg bx, bx` to break in Bochs.
- **QEMU + GDB**: run with `-s -S`, `target remote :1234`, `set architecture i8086`.

---

## 16) Risks & Mitigations

- **Size overrun** → keep palette procedural; remove vsync; compress loops.
- **Tearing** → add minimal vsync or accept for 512B.
- **Random wrap at line edges** → mask x with `(W-1)` or clamp.
- **Real-hardware variance** → prefer simple DAC programming; avoid quirky VGA modes.

---

## 17) Roadmap (Post-512B)

- Load a **second stage** (INT 13h) to add features (text overlay, UI).
- Add **double buffering** for clean reads/writes.
- Add **logo** or **text scroller**.
- Experiment with **Mode X** (planar) for fun.

---
