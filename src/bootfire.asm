; =========================================
; Bootfire
;
; single-stage boot sector demo
; sets video mode, installs palette
; runs doom fire algortihm in 512 bytes
; v0.1.0
; =========================================


; Physical address of bootsector
; On IBM compatible machine
ORG 0x7C00 

; -------- CONSTANTS ---------
SCREEN_W        equ
SCREEN_H        equ
PALETTE_SIZE    equ
COLOR_MAX       equ
VRAM_SEG        equ
FIRE_BUF_SEG    equ
STACK_SEG       equ
STACK_TOP       equ

; -------- HARDWARE PORTS ----
PORT_DAC_INDEX  equ
PORT_DAC_DATA   equ
PORT_VSYNC      equ

; -------- BIOS SERVICES -----
BIOS_VMODE      equ
BIOS_TEXTMODE   equ
INT_VIDEO       equ
INT_KEYBOARD    equ

; -------- EXTERNAL DATA -----
include "palette.inc"

; -------- ENTRY POINT -------
start:

; -------- INITIALIZATION ----
set_stack:
set_video_mode:
install_palette:
init_fire_buffer:

; -------- MAIN LOOP ---------
main_loop:
    propagate_fire_one_frame:
    blit_fire_to_vram:
    vsync_wait:
    check_key_exit:
jmp main_loop

; -------- RANDOM NUMBER -----
rng_seed:
rand8:
rand2:

; -------- DATA AREA ---------
fire_buf_ptr:
tmp_vars:

; -------- TERMINATION -------
hang:

; -------- BOOT SIGNATURE ----
pad_to_510:
    times 510-($-$$) db 0
    dw 0xAA55
