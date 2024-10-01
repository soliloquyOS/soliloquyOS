org 0x7c00
bits 16
%define ENDL 0x0D, 0x0A

;FAT12 Header
jmp short start
nop

bdb_oem:                    db 'slqy-os '       ;8 bytes
bdb_bytes_per_sector:       dw 512
bdb_sectors_per_cluster:    db 1
bdb_reserved_sectors:       dw 1
bdb_fat_count:              db 2
bdb_dir_entries_count:      dw 0E0h
bdb_total_sectors:          dw 2880             ;2880 * 512 = 1.44mb
bdb_media_descriptor_type:  db 0F0h             ; F0 = 3.5" floppy disk
bdb_sectors_per_fat:        dw 9                ; 9 sectors/fat
bdb_sectors_per_track:      dw 18
bdb_heads:                  dw 2
bdb_hidden_sectors:         dd 0
bdb_large_sector_count:     dd 0

;extended boot record
ebr_drive_number:           db 0 ;0x00 floppy, 0x80 hdd, useless
                            db 0 ;reserved
ebr_signature:              db 29h
ebr_volume_id:              db 12h, 34h, 56h, 78h   ;serial number, value doesn't matter
ebr_volume_label:           db 'soliloquyos'
ebr_system_id:              db 'FAT12   '           ;8 bytes

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

;Disk Routines

;Converts lba address to chs address
;parameters:
;    - ax: an lba address
; returns
;   - cx [bits 0 - 5]: sector number
;   - cx [bits 6 - 15]: cylinder
;   - dh: head
lba_to_chs:
    push ax
    push dx

    xor dx, dx      ;dx = 0
    div word [bdb_sectors_per_track]        ;ax = LBA / SectorsPerTrack
                                            ;dx = LBA % SectorsPerTrack

    inc dx                                  ;dx = (LBA % SectorsPerTrack + 1) = sector
    mov cx, dx                              ;cx = sector

    xor = dx, dx                            ;dx = 0
    div word [bdb_heads]                    ;ax = (LBA / SectorsPerTrack) / Heads = cylinder
                                            ;dx = (LBA / SectorsPerTrack) % Heads = head
    mov dh, dl                              ;dh = head
    mov ch, al                              ; ch = cylinder (lower 8 bits)
    shl ah, 6
    or cl, ah                               ;put upper 2 bits of cyliner in CL

    pop ax
    mov dl, al                              ;restore DL
    pop ax
    ret

msg_welcome: db 'Welcome to Soliloquy OS!', ENDL, 0
times 510-($-$$) db 0
dw 0AA55h