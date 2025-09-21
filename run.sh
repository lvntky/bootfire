#!/usr/bin/env bash
# run.sh — assemble bootsector, make a 1.44MB image, run in QEMU
# deps: fasm, qemu-system-i386, dd, hexdump (optional)

set -euo pipefail

# ---------- config ----------
ASM=${ASM:-fasm}
QEMU=${QEMU:-qemu-system-i386}
SRC=${SRC:-src/bootfire.asm}
BUILD_DIR=${BUILD_DIR:-build}
BOOT_BIN=${BOOT_BIN:-$BUILD_DIR/bootfire.bin}
IMG=${IMG:-$BUILD_DIR/boot.img}
IMG_SIZE_KB=${IMG_SIZE_KB:-1440}     # 1.44MB
QEMU_RAM=${QEMU_RAM:-16}             # MB
QEMU_VGA=${QEMU_VGA:-std}            # or "vmware","cirrus"
QEMU_FLAGS_DEFAULT=(
  -fda "$IMG"
  -boot a
  -m "$QEMU_RAM"
  -vga "$QEMU_VGA"
  -no-reboot
  -no-shutdown
  -monitor stdio
  -d guest_errors
)
# ----------------------------

usage() {
  cat <<EOF
Usage: $0 [options]

Options:
  --rebuild       Force rebuild image even if it exists
  --gdb           Start paused and listen on tcp:1234 for GDB
  --kvm           Enable KVM acceleration (if supported)
  --trace         Verbose QEMU tracing (cpu,in_asm)
  --img PATH      Override image output path (default: $IMG)
  --src PATH      Override bootsector source (default: $SRC)
  --no-run        Build only; don't launch QEMU
  -h, --help      Show this help
EOF
  exit 0
}

REBUILD=0
WITH_GDB=0
WITH_KVM=0
WITH_TRACE=0
NO_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --rebuild) REBUILD=1 ;;
    --gdb)     WITH_GDB=1 ;;
    --kvm)     WITH_KVM=1 ;;
    --trace)   WITH_TRACE=1 ;;
    --img)     IMG="$2"; shift ;;
    --src)     SRC="$2"; shift ;;
    --no-run)  NO_RUN=1 ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
  shift
done

mkdir -p "$BUILD_DIR"

# 1) assemble boot sector
echo "[1/4] Assembling: $SRC -> $BOOT_BIN"
$ASM "$SRC" "$BOOT_BIN"

# 2) ensure 512 bytes and boot signature 0x55AA
size=$(stat -c%s "$BOOT_BIN")
if (( size < 512 )); then
  echo "Padding boot sector to 512 bytes (had $size)..."
  dd if=/dev/zero bs=1 count=$((512 - size)) status=none >> "$BOOT_BIN"
  size=512
fi

if (( size != 512 )); then
  echo "ERROR: boot sector must be exactly 512 bytes (got $size)"; exit 1
fi

# write signature if missing
sig=$(hexdump -v -e '1/1 "%02X"' -s 510 -n 2 "$BOOT_BIN" 2>/dev/null || echo "")
if [[ "$sig" != "55AA" ]]; then
  echo "Boot signature missing; injecting 0x55AA at bytes 510..511"
  printf '\x55\xAA' | dd of="$BOOT_BIN" bs=1 seek=510 conv=notrunc status=none
fi

# 3) create floppy image and write boot sector
if [[ $REBUILD -eq 1 || ! -f "$IMG" ]]; then
  echo "[2/4] Creating floppy image: $IMG ($IMG_SIZE_KB KB)"
  dd if=/dev/zero of="$IMG" bs=1024 count="$IMG_SIZE_KB" status=none
fi

echo "[3/4] Writing boot sector to image"
dd if="$BOOT_BIN" of="$IMG" conv=notrunc bs=512 count=1 status=none

if [[ $NO_RUN -eq 1 ]]; then
  echo "[4/4] Build done (not running). Image at: $IMG"
  exit 0
fi

# 4) run in QEMU
echo "[4/4] Launching QEMU"
QFLAGS=("${QEMU_FLAGS_DEFAULT[@]}")

if [[ $WITH_GDB -eq 1 ]]; then
  QFLAGS+=(-S -gdb tcp:localhost:1234)
  echo "GDB server on tcp:1234 (target remote :1234)"
fi
if [[ $WITH_KVM -eq 1 ]]; then
  QFLAGS+=(-accel kvm)
fi
if [[ $WITH_TRACE -eq 1 ]]; then
  QFLAGS+=(-D "$BUILD_DIR/qemu.log" -d cpu,guest_errors,in_asm)
  echo "QEMU trace at $BUILD_DIR/qemu.log"
fi

exec "$QEMU" "${QFLAGS[@]}"
