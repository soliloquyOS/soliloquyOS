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
ebr_volume_label:           db 'soliloquyos'        ;11 bytes, padded w/ spaces
ebr_system_id:              db 'FAT12   '           ;8 bytes

start:
    ; setup data segments
    mov ax, 0                   ; can't write to ds/es directly
    mov ds, ax
    mov es, ax
    
    ; setup stack
    mov ss, ax
    mov sp, 0x7C00              ; stack grows downwards from where we were loaded in memory

    ;some bios might start at 07C0:0000 instead of 0000:7C00. this fixes that
    push es
    push word .after
    retf

.after:

    ; read something from floppy
    ; bios should set dl to drive number
    mov [ebr_drive_number], dl

    ;show loading message
    mov si, msg_welcome
    call puts

    ;read drive parameters (sectors per track & head count),
    ; instead of relying on data on formatted disk
    push es
    mov ah, 08h
    int 13h
    jc floppy_error
    pop es

    and cl, 0x3F                ;remove top 2 bits
    xor ch, ch
    mov [bdb_sectors_per_track], cx ; sector count

    inc dh
    mov [bdb_heads], dh             ; head count

    ;compute LBA of root directory = reserved + fats * sectors_per_fat
    ;note: this section can be hard coded
    mov ax, [bdb_sectors_per_fat]
    mov bl, [bdb_fat_count]
    xor bh, bh
    mul bx                      ;dx:ax = (fats * sectors_per_fat)
    add ax, [bdb_reserved_sectors]      ; ax = LBAof root directory
    push ax

    ;compute size of root directory = (32 * number_of_entries) / bytes_per_sector
    mov ax, [bdb_sectors_per_fat]
    shl ax, 5                   ;ax *= 32
    xor dx, dx                  ;dx = 0
    div word [bdb_bytes_per_sector]     ;number of sectors we need to read

    test dx, dx
    jz root_dir_after
    inc ax      ;division remainder != 0, add 1
                ; this means we have a sector only partially filled with entries

.root_dir_after:
    ;read root directory
    mov cl, al                  ;cl = # of sectors to read = size of root directory
    pop ax                      ;ax = LBA of root directory
    mov dl, [ebr_drive_number]  ;dl = drive number
    mov bx, buffer              ;es:bx = buffer
    call disk_read

    ;search for kernel.bin
    xor bx, bx
    mov di, buffer

.search_kernel:
    mov si, file_kernel_bin
    mov cx, 11                  ;compare up to 11 characters
    push di
    repe cmpsb
    pop di
    je .found_kernel

found_kernel:

    cli                         ; disable interrupts so cpu can't leave halt state
    hlt


;
; Error handlers
;

floppy_error:
    mov si, msg_read_failed
    call puts
    jmp wait_key_and_reboot

wait_key_and_reboot:
    mov ah, 0
    int 16h                     ; wait for keypress
    jmp 0FFFFh:0                ; jump to beginning of bios, should reboot

.halt:
    cli                         ; disable interrupts so cpu can't leave halt state
    hlt


;
; Disk routines
;

;
; Converts an LBA address to a CHS address
; Parameters:
;   - ax: LBA address
; Returns:
;   - cx [bits 0-5]: sector number
;   - cx [bits 6-15]: cylinder
;   - dh: head
;

lba_to_chs:

    push ax
    push dx

    xor dx, dx                          ; dx = 0
    div word [bdb_sectors_per_track]    ; ax = LBA / SectorsPerTrack
                                        ; dx = LBA % SectorsPerTrack

    inc dx                              ; dx = (LBA % SectorsPerTrack + 1) = sector
    mov cx, dx                          ; cx = sector

    xor dx, dx                          ; dx = 0
    div word [bdb_heads]                ; ax = (LBA / SectorsPerTrack) / Heads = cylinder
                                        ; dx = (LBA / SectorsPerTrack) % Heads = head
    mov dh, dl                          ; dh = head
    mov ch, al                          ; ch = cylinder (lower 8 bits)
    shl ah, 6
    or cl, ah                           ; put upper 2 bits of cylinder in CL

    pop ax
    mov dl, al                          ; restore DL
    pop ax
    ret


;
; Reads sectors from a disk
; Parameters:
;   - ax: LBA address
;   - cl: number of sectors to read (up to 128)
;   - dl: drive number
;   - es:bx: memory address where to store read data
;
disk_read:

    push ax                             ; save registers we'll modify
    push bx
    push cx
    push dx
    push di

    push cx                             ; temporarily save CL (number of sectors to read)
    call lba_to_chs                     ; compute CHS
    pop ax                              ; AL = number of sectors to read
    
    mov ah, 02h
    mov di, 3                           ; retry count

.retry:
    pusha                               ; save all registers, don't know what bios modifies
    stc                                 ; set carry flag, some bios don't set it
    int 13h                             ; carry flag cleared = success
    jnc .done                           ; jump if carry not set

    ; read failed
    popa
    call disk_reset

    dec di
    test di, di
    jnz .retry

.fail:
    ; all attempts are exhausted
    jmp floppy_error

.done:
    popa

    pop di
    pop dx
    pop cx
    pop bx
    pop ax                             ; restore modified registers
    ret


;
; Resets disk controller
; Parameters:
;   dl: drive number
;
disk_reset:
    pusha
    mov ah, 0
    stc
    int 13h
    jc floppy_error
    popa
    ret



msg_loading:     db 'Loading...', ENDL, 0
msg_read_failed: db 'Read from disk failed!', ENDL, 0
file_kernel_bin:        db 'KERNEL  BIN'
times 510-($-$$) db 0
dw 0AA55h

buffer: