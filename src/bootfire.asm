; Bootfire
;
; =========================================
; single-stage boot sector demo
; sets video mode, installs palette
; runs doom fire algortihm in 512 bytes
; v0.1.0
; =========================================
; Physical address of bootsector
; On IBM compatible machine
ORG 0x7C00
        ; -------- CONSTANTS ---------
        PORT_DAC_INDEX equ 0x3C8
        PORT_DAC_WRITE equ 0x3C9
        VRAM_SEG        equ 0xA000
        SCREEN_W        equ 320
        SCREEN_H        equ 200
        
start:
        call set_video_mode
        call load_palette_to_dac
        call draw_test_bars
        call halt
halt:
        jmp halt



set_video_mode:
        mov ax, 0x13
        int 0x10
        ret

load_palette_to_dac:
        mov dx, PORT_DAC_INDEX
        xor al, al
        out dx, al

        mov dx, PORT_DAC_WRITE
        mov si, fire_palette_data
        mov cx, fire_palette_end - fire_palette_data
        rep outsb
        ret



draw_test_bars:
        push ax
        push es
        push di

        mov ax, VRAM_SEG
        mov es, ax
        xor di, di              ; ES:DI -> A000:0000

        xor bx, bx              ; BX = current color (0..36)
        mov dx, SCREEN_H        ; outer loop: rows = 200

.y_loop:
        mov cx, SCREEN_W        ; inner loop: columns = 320
.x_loop:
        mov al, bl              ; AL = color
        stosb                   ; [ES:DI++] = AL

        inc bl                  ; next color
        cmp bl, 37
        jb  .no_wrap
        xor bl, bl              ; wrap to 0
.no_wrap:
        loop .x_loop

        dec dx
        jnz .y_loop

        pop di
        pop es
        pop ax
        ret
        
include 'palette.inc'
; -------- BOOT SIGNATURE ----
times 510-($-$$) db 0
dw 0xAA55
