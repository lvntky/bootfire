#!/usr/bin/env bash
# run.sh — assemble bootsector, make a 1.44MB image, run in QEMU with debugging support
# deps: nasm, qemu-system-i386, dd, hexdump (optional), gf (optional)
set -euo pipefail

# ---------- config ----------
ASM=${ASM:-nasm}
QEMU=${QEMU:-qemu-system-i386}
SRC=${SRC:-src/bootfire.asm}
BUILD_DIR=${BUILD_DIR:-build}
BOOT_BIN=${BOOT_BIN:-$BUILD_DIR/bootfire.bin}
IMG=${IMG:-$BUILD_DIR/boot.img}
IMG_SIZE_KB=${IMG_SIZE_KB:-1440} # 1.44MB
QEMU_RAM=${QEMU_RAM:-16} # MB
QEMU_VGA=${QEMU_VGA:-std} # or "vmware","cirrus"
GDB_PORT=${GDB_PORT:-1234}

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

Build Options:
  --rebuild        Force rebuild image even if it exists
  --img PATH       Override image output path (default: $IMG)
  --src PATH       Override bootsector source (default: $SRC)
  --no-run         Build only; don't launch QEMU

Debug Options:
  --debug          Start with GDB server and launch gf GUI debugger
  --gdb            Start paused and listen on tcp:$GDB_PORT for GDB (no GUI)
  --gdb-wait       Like --debug but wait for manual GDB connection
  --gdb-port PORT  GDB server port (default: $GDB_PORT)

Runtime Options:  
  --kvm            Enable KVM acceleration (if supported)
  --trace          Verbose QEMU tracing (cpu,in_asm)
  
  -h, --help       Show this help

Examples:
  $0                     # Normal run
  $0 --debug             # Run with gf GUI debugger
  $0 --gdb               # Run with GDB server, no GUI
  $0 --gdb-wait          # Start GDB server, wait for connection
  $0 --rebuild --debug   # Force rebuild and debug
EOF
exit 0
}

# Parse arguments
REBUILD=0
WITH_GDB=0
WITH_DEBUG_GUI=0
WITH_KVM=0
WITH_TRACE=0
NO_RUN=0
GDB_WAIT=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --rebuild) REBUILD=1 ;;
        --debug) WITH_DEBUG_GUI=1; WITH_GDB=1 ;;
        --gdb) WITH_GDB=1 ;;
        --gdb-wait) WITH_GDB=1; GDB_WAIT=1 ;;
        --gdb-port) GDB_PORT="$2"; shift ;;
        --kvm) WITH_KVM=1 ;;
        --trace) WITH_TRACE=1 ;;
        --img) IMG="$2"; shift ;;
        --src) SRC="$2"; shift ;;
        --no-run) NO_RUN=1 ;;
        -h|--help) usage ;;
        *) echo "Unknown option: $1"; usage ;;
    esac
    shift
done

mkdir -p "$BUILD_DIR"

# 1) Assemble boot sector
echo "[1/4] Assembling: $SRC -> $BOOT_BIN"
$ASM "$SRC" -o "$BOOT_BIN"

# 2) Ensure 512 bytes and boot signature 0x55AA
size=$(stat -c%s "$BOOT_BIN")
if (( size < 512 )); then
    echo "Padding boot sector to 512 bytes (had $size)..."
    dd if=/dev/zero bs=1 count=$((512 - size)) status=none >> "$BOOT_BIN"
    size=512
fi

if (( size != 512 )); then
    echo "ERROR: boot sector must be exactly 512 bytes (got $size)"; exit 1
fi

# Write signature if missing
sig=$(hexdump -v -e '1/1 "%02X"' -s 510 -n 2 "$BOOT_BIN" 2>/dev/null || echo "")
if [[ "$sig" != "55AA" ]]; then
    echo "Boot signature missing; injecting 0x55AA at bytes 510..511"
    printf '\x55\xAA' | dd of="$BOOT_BIN" bs=1 seek=510 conv=notrunc status=none
fi

# 3) Create floppy image and write boot sector
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

# Create GDB init script for bootloader debugging
create_gdb_init() {
    cat > "$BUILD_DIR/gdbinit" << 'EOF'
# GDB init for bootloader debugging
set confirm off
set pagination off

# Connect to QEMU
target remote :1234

# Set architecture to 16-bit (bootloader starts in real mode)
set architecture i8086

# Useful functions for bootloader debugging
define hook-stop
    # Show registers and next instruction on every stop
    info registers
    x/i $pc
end

define hook-run
    echo \n--- Starting execution ---\n
end

define hook-continue
    echo \n--- Continuing execution ---\n
end

# Custom commands
define dump_sector
    if $argc == 0
        set $addr = 0x7c00
    else
        set $addr = $arg0
    end
    printf "Dumping 512 bytes from 0x%x:\n", $addr
    x/32bx $addr
    x/32bx $addr+32
    x/32bx $addr+64
    x/32bx $addr+96
end

define bootloader_info
    echo \n=== Bootloader Debug Info ===\n
    printf "Boot signature at 0x7dfe: 0x%04x (should be 0xaa55)\n", *(unsigned short*)0x7dfe
    printf "Current CS:IP = 0x%04x:0x%04x\n", $cs, $ip
    printf "Stack at SS:SP = 0x%04x:0x%04x\n", $ss, $sp
    echo \n--- Bootloader code (first 16 bytes) ---
    x/16bx 0x7c00
    echo \n
end

# Set initial breakpoint at bootloader entry
break *0x7c00

echo \n=== GDB Ready for Bootloader Debugging ===
echo Commands available:
echo   dump_sector [addr]  - Dump 512 bytes (default: 0x7c00)
echo   bootloader_info     - Show bootloader debug info
echo   c                   - Continue execution
echo   s                   - Step instruction
echo   si                  - Step into
echo \n
EOF
}

# 4) Run in QEMU with optional debugging
echo "[4/4] Launching QEMU"

QFLAGS=("${QEMU_FLAGS_DEFAULT[@]}")

if [[ $WITH_KVM -eq 1 ]]; then
    QFLAGS+=(-accel kvm)
fi

if [[ $WITH_TRACE -eq 1 ]]; then
    QFLAGS+=(-D "$BUILD_DIR/qemu.log" -d cpu,guest_errors,in_asm)
    echo "QEMU trace at $BUILD_DIR/qemu.log"
fi

if [[ $WITH_GDB -eq 1 ]]; then
    QFLAGS+=(-S -gdb tcp:localhost:$GDB_PORT)
    create_gdb_init
    
    echo "=== GDB Debugging Enabled ==="
    echo "GDB server on tcp:localhost:$GDB_PORT"
    echo "GDB init script: $BUILD_DIR/gdbinit"
    
    if [[ $WITH_DEBUG_GUI -eq 1 ]]; then
        # Check if gf2 is available
        if ! command -v gf2 &> /dev/null; then
            echo "WARNING: 'gf2' not found. Install with: cargo install gf2"
            echo "Falling back to command-line GDB..."
            WITH_DEBUG_GUI=0
        fi
    fi
    
    # Start QEMU in background
    "$QEMU" "${QFLAGS[@]}" &
    QEMU_PID=$!
    
    # Give QEMU time to start
    sleep 1
    
    if [[ $WITH_DEBUG_GUI -eq 1 ]]; then
        echo "Starting gf2 GUI debugger..."
        # Find gdb path
        GDB_PATH=$(which gdb 2>/dev/null || echo "gdb")
        echo "Using GDB at: $GDB_PATH"
        
        # Start gf2 and let user configure it manually
        gf2 &
        GDB_PID=$!
        
        echo ""
        echo "=== gf2 Configuration Required ==="
        echo "In gf2 GUI:"
        echo "1. Path to executable: $GDB_PATH"
        echo "2. Command line arguments: -x $BUILD_DIR/gdbinit"
        echo "3. Click 'Start'"
        echo "4. In GDB console, type: target remote :$GDB_PORT"
        echo ""
        echo "Or use --gdb flag for command-line debugging instead"
        echo ""
        
        
        # Wait for either process to finish
        wait $QEMU_PID 2>/dev/null || wait $GDB_PID 2>/dev/null
        
        # Clean up remaining processes
        kill $QEMU_PID 2>/dev/null || true
        kill $GDB_PID 2>/dev/null || true
    elif [[ $GDB_WAIT -eq 1 ]]; then
        echo ""
        echo "QEMU started and waiting for GDB connection."
        echo "Connect with: gdb -x $BUILD_DIR/gdbinit"
        echo "Or manually: gdb -> target remote :$GDB_PORT"
        echo ""
        echo "Press Ctrl+C to stop QEMU"
        wait $QEMU_PID
    else
        echo "Starting command-line GDB..."
        gdb -x "$BUILD_DIR/gdbinit"
        kill $QEMU_PID 2>/dev/null || true
    fi
else
    # Normal run without debugging
    exec "$QEMU" "${QFLAGS[@]}"
fi
