org 0x0
bits 16


%define ENDL 0x0D, 0x0A


start:
    ; print welcome message
    mov si, msg_welcome
    call puts

.halt:
    cli
    hlt

;
; Prints a string to the screen
; Params:
;   - ds:si points to string
;
puts:
    ; save registers we'll modify
    push si
    push ax
    push bx

.loop:
    lodsb               ; loads next character in al
    or al, al           ; verify: is next character null?
    jz .done

    mov ah, 0x0E        ; call bios interrupt
    mov bh, 0           ; set page number to 0
    int 0x10

    jmp .loop

.done:
    pop bx
    pop ax
    pop si    
    ret

msg_welcome: db 'Welcome to soliloquyOS!', ENDL, 0