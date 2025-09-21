#!/usr/bin/env python3
"""
gen_palette.py — DOOM fire palette generator (for VGA DAC, 0..63 per channel)

Outputs FASM-friendly lines like:
    ; index 00
    db 0,0,0
    ; index 01
    db 1,0,0
    ...

Usage examples:
  # Write 37-entry ramp to src/palette.inc (FASM format, default)
  python3 tools/gen_palette.py --size 37 --outfile src/palette.inc

  # Print to stdout in 'hex' (0x00..0x3F) format
  python3 tools/gen_palette.py --size 48 --format hex

  # Raw binary (RGB triplets) to a file
  python3 tools/gen_palette.py --format raw --outfile build/palette.bin
"""

import argparse
from pathlib import Path
import sys
import math

def lerp(a, b, t):
    return a + (b - a) * t

def srgb_to_linear(c):
    # c in [0,1] sRGB -> linear
    if c <= 0.04045:
        return c / 12.92
    return ((c + 0.055) / 1.055) ** 2.4

def linear_to_srgb(c):
    # clamp
    c = max(0.0, min(1.0, c))
    if c <= 0.0031308:
        return 12.92 * c
    return 1.055 * (c ** (1.0 / 2.4)) - 0.055

def apply_gamma(rgb, gamma):
    # gamma>0: simple power gamma; 'srgb' uses sRGB transfer
    r, g, b = rgb
    if gamma == "srgb":
        # Assume input in sRGB; convert to linear, then back after lerp (handled elsewhere)
        return (r, g, b)
    else:
        gpow = float(gamma)
        return (r ** (1.0 / gpow), g ** (1.0 / gpow), b ** (1.0 / gpow))

def to_dac(v):
    # Scale [0,1] -> [0,63] with rounding
    return max(0, min(63, int(round(v * 63.0))))

def interpolate_stops(stops, t, gamma_mode):
    """
    stops: list of (pos, (r,g,b)) where pos in [0,1], colors in 0..1 sRGB
    gamma_mode: 'srgb' or float string (e.g., '2.2')
    """
    # find segment
    if t <= stops[0][0]:
        c = stops[0][1]
    elif t >= stops[-1][0]:
        c = stops[-1][1]
    else:
        for i in range(len(stops) - 1):
            p0, c0 = stops[i]
            p1, c1 = stops[i + 1]
            if p0 <= t <= p1:
                u = (t - p0) / (p1 - p0)
                if gamma_mode == "srgb":
                    # Lerp in linear-light for perceptual smoothness
                    c0_lin = tuple(srgb_to_linear(x) for x in c0)
                    c1_lin = tuple(srgb_to_linear(x) for x in c1)
                    cl = (
                        lerp(c0_lin[0], c1_lin[0], u),
                        lerp(c0_lin[1], c1_lin[1], u),
                        lerp(c0_lin[2], c1_lin[2], u),
                    )
                    c = tuple(linear_to_srgb(x) for x in cl)
                else:
                    # Simple component-wise lerp, then apply gamma afterwards
                    c = (
                        lerp(c0[0], c1[0], u),
                        lerp(c0[1], c1[1], u),
                        lerp(c0[2], c1[2], u),
                    )
                break

    if gamma_mode != "srgb":
        c = apply_gamma(c, gamma_mode)
    return c

def build_fire_palette(size, gamma_mode):
    """
    Returns list of (r,g,b) in DAC units 0..63, length = size.
    """
    # Key DOOM-like stops (positions normalized 0..1), sRGB 0..1
    stops = [
        (0.00, (0.00, 0.00, 0.00)),  # black
        (0.15, (0.20, 0.00, 0.00)),  # deep red
        (0.35, (0.80, 0.00, 0.00)),  # red
        (0.55, (1.00, 0.35, 0.00)),  # orange
        (0.75, (1.00, 0.75, 0.10)),  # yellowish
        (1.00, (1.00, 1.00, 1.00)),  # white-hot
    ]

    pal = []
    for i in range(size):
        t = i / (size - 1) if size > 1 else 0.0
        r, g, b = interpolate_stops(stops, t, gamma_mode)
        pal.append((to_dac(r), to_dac(g), to_dac(b)))
    return pal

def write_fasm(pal, label, fp):
    print(f"{label}:", file=fp)
    for i, (r, g, b) in enumerate(pal):
        print(f"  ; index {i:02d}", file=fp)
        print(f"  db {r},{g},{b}", file=fp)

def write_hex(pal, fp):
    for r, g, b in pal:
        print(f"0x{r:02X} 0x{g:02X} 0x{b:02X}")

def write_raw(pal, fp):
    b = bytearray()
    for r, g, bch in pal:
        b.extend([r, g, bch])
    fp.buffer.write(b)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--size", type=int, default=37, help="number of palette entries (e.g., 36–48)")
    ap.add_argument("--gamma", default="srgb", help="'srgb' or a float gamma like 2.2")
    ap.add_argument("--format", choices=["fasm", "hex", "raw"], default="fasm")
    ap.add_argument("--label", default="FirePalette", help="label name for fasm format")
    ap.add_argument("--outfile", default="", help="output file; stdout if omitted")
    args = ap.parse_args()

    pal = build_fire_palette(args.size, args.gamma)

    if args.outfile:
        Path(args.outfile).parent.mkdir(parents=True, exist_ok=True)

    if args.format == "fasm":
        if args.outfile:
            with open(args.outfile, "w", encoding="utf-8") as f:
                write_fasm(pal, args.label, f)
        else:
            write_fasm(pal, args.label, sys.stdout)
    elif args.format == "hex":
        if args.outfile:
            with open(args.outfile, "w", encoding="utf-8") as f:
                for r, g, b in pal:
                    f.write(f"0x{r:02X} 0x{g:02X} 0x{b:02X}\n")
        else:
            write_hex(pal, sys.stdout)
    else:  # raw
        if args.outfile:
            with open(args.outfile, "wb") as f:
                b = bytearray()
                for r, g, bch in pal:
                    b.extend([r, g, bch])
                f.write(b)
        else:
            write_raw(pal, sys.stdout)

if __name__ == "__main__":
    main()

