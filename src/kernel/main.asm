org 0x7c00
bits 16
%define ENDL 0x0D, 0x0A

start:
    jmp main
    
;prints a string to the screen
;params:
;   - ds:si points to string
puts:
    ; save registers to be modified
    push si
    push ax
.loop:
    lodsb       ;loads next character in al
    or al, al   ;verify: is the next character null?
    jz .done
    mov ah, 0x0e        ; call bios interrupt
    mov bh, 0
    int 0x10
    jmp .loop
.done:
    pop ax
    pop si
    ret

main:
    ; set up data segments
    mov ax, 0           ; can't write to ds/es directly
    mov ds, ax
    mov es, ax
    ; set up stack
    mov ss, ax
    mov sp, 0x7c00      ; stack grows downwards from where we were loaded in memory 
    ;prints message
    mov si, msg_welcome
    call puts
    cli
    hlt
.halt:
    jmp .halt

msg_welcome: db 'Welcome to Soliloquy OS!', ENDL, 0
times 510-($-$$) db 0
dw 0AA55h