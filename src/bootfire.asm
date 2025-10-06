[BITS 16]
[ORG 0x7C00]

start:
    xor ax, ax
    mov ds, ax
    mov es, ax
    
    ; Set video mode 13h (320x200, 256 colors)
    mov ax, 0x0013
    int 0x10
    
    ; Load custom fire palette to DAC
    xor ax, ax              ; Start at palette index 0
    mov dx, 0x03C8          ; DAC write index register
    out dx, al              ; Set starting palette index to 0
    
    mov si, fire_palette_data
    mov cx, 37 * 3          ; 37 colors * 3 bytes each = 111 bytes total
    inc dx                  ; DX = 0x03C9 (DAC data register)
    
load_palette:
    lodsb                   ; Load byte into AL and increment SI
    out dx, al              ; Write to DAC
    loop load_palette
    
    ; Fill screen with color index 20 (bright orange/yellow)
    mov ax, 0xA000          ; Video memory segment
    mov es, ax
    xor di, di              ; Start at offset 0
    mov cx, 64000           ; 320x200 = 64000 pixels
    mov al, 27              ; Color index to use
    rep stosb               ; Fill video memory
    
    ; Infinite loop
hang:
    hlt
    jmp hang

; Include the palette data from external file
%include "src/palette.inc"

; Boot sector signature
times 510-($-$$) db 0
dw 0xAA55
