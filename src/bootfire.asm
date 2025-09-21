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
SCREEN_W equ 320
SCREEN_H equ 200
PALETTE_SIZE equ 256
COLOR_MAX equ 255
VRAM_SEG equ 0xA000
FIRE_BUF_SEG equ 0x8000
STACK_SEG equ 0x7000
STACK_TOP equ 0xFFFE
PIXELS equ SCREEN_W * SCREEN_H
; -------- HARDWARE PORTS ----
PORT_DAC_INDEX equ 0x3C8
PORT_DAC_DATA equ 0x3C9
PORT_VSYNC equ 0x3DA
; -------- BIOS SERVICES -----
BIOS_VMODE equ 0x00
BIOS_TEXTMODE equ 0x03
INT_VIDEO equ 0x10
INT_KEYBOARD equ 0x16

; -------- ENTRY POINT -------
start:
    ; set stack
    mov ax, STACK_SEG
    mov ss, ax
    mov sp, STACK_TOP

; -------- MAIN LOOP ---------
main_loop:
    call propagate_fire_one_frame
    call blit_fire_to_vram
    call vsync_wait
    call check_key_exit
    jmp main_loop

; -------- FIRE ALGORITHM ----
propagate_fire_one_frame:
    
    ret

blit_fire_to_vram:
    
    ret

vsync_wait:
    
    ret

check_key_exit:
    
    ret

; -------- RANDOM NUMBER -----
rng_seed: dw 1

rand8:
    ret

rand2:
    
    ret

; -------- DATA AREA ---------
fire_buf_ptr: dw 0
tmp_vars: dw 0

; -------- TERMINATION -------
hang:
    jmp hang


include 'palette.inc'
; -------- BOOT SIGNATURE ----
times 510-($-$$) db 0
dw 0xAA55