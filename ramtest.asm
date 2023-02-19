;
; EC1834 RAM Extension board test program
; Copyright (c)2023 Mario Goegel
;
; Licensed under GPL v3
;
; requires more comments
;
; $ nasm -f bin -o hedosexe.exe hedosexe.nasm
;
USE16
%include "fullprog_dosexe.inc.nasm"

RAMEXT_START EQU 4000h
LOOPSIZE EQU 1000h ; output every x adresses current position
LOOPS0   EQU 8  ; how many loops are required for a complete segment - keep in mind, that we check only every 2nd byte

fullprog_code

; mov ah, 9  ; WRITE_STDOUT.
; mov dx, msg
; int 0x21  ; http://spike.scu.edu.au/~barry/interrupts.html

START:
    mov si,msg
    call OUTPUT_TEXT

getInput:
    mov ah,00h
    int 16h
    CALL OUTPUT_CHR
    CALL OUTPUT_CRLF
    sub al,30h 
    or al,al ; 0 for exit?
    jz QUIT

    cmp al, 1
    jne .next1
    sub di,di ; start with offset fffe
    dec di
    dec di
    mov si, msg_test1
    call OUTPUT_TEXT
    call TEST1
.next1:

    cmp al, 2
    jne .next2
    sub di,di ; start with offset ffff
    dec di
    mov si, msg_test2
    call OUTPUT_TEXT
    call TEST1
.next2:

.next9:
    jmp START

QUIT:
    mov si, msg_bye
    call OUTPUT_TEXT
    mov ax,0x4c00
    int 0x21
    ret

; TEST SEGMENT 4xxxx with even numbers
; set di to start offset
TEST1:
    mov si, msg_test1_1
    call OUTPUT_TEXT
    mov BYTE [cnt_error], 0
    mov BYTE [sig_abort], 0
    mov BYTE [tst_byte], 0

    push bx
    push es
    push di
    ;cld

    ; init offset/data
    ; sub di,di
    sub ax,ax
    mov cx,LOOPSIZE
    mov dl,8

    ; Disable NMI (Parity error)
    mov al,0
    out 0xa0, al
    mov ah,BYTE [tst_byte] ; init compare value for test
    mov al,BYTE [tst_byte] ; init value for test
    ;call OUTPUT_HEX_DIGIT4
    ;call OUTPUT_CR
    ; init start segment
    mov bx,RAMEXT_START
    mov es,bx
.loop_test1:
    mov al,BYTE [tst_byte] ; init value for test
    mov es:[di],al
    mov al,es:[di]
    push ax
    xor al,ah   ; Zero flag set, when equal
    pop ax
    jz .OK1     ; zero, so value is equal
    ; ERROR CONDITION HERE
    ;call PRINT_ERRADDR
    ;call ERRORCNT_WAIT ; press "q" for abort
    cmp BYTE [sig_abort], 1
    jz .loop0_end ; abort requested
.OK1:
    dec di
    dec di ; inc by 2
    mov ax, 0
    loop .loop_test1
    
    ; print current test offset
    add di,2
    ;call OUTPUT_HEX_DIGIT4
    ;call OUTPUT_CR
    sub di,2

    ; decrease outer loop counter
    dec dl
    jz .loop0_end ; exit when done
    mov cx, LOOPSIZE
    jmp .loop_test1 ; another round
.loop0_end:
    mov al, 0x80
    out 0xa0, al
    pop di
    pop es
    pop bx
    mov di, msg_test1_3
    call OUTPUT_TEXT
    call OUTPUT_CRLF
    call OUTPUT_CRLF
    ret


ERRORCNT_WAIT:
    inc BYTE[cnt_error]
    cmp BYTE[cnt_error], 10
    jnz .no_wait_t0
    mov BYTE[cnt_error], 0
    call WAIT_CHR
.no_wait_t0:
    ret

PRINT_ADDR:
    push ax
    mov al, "."
    call OUTPUT_CHR
    pop ax
    ret
    
PRINT_ERRADDR:
    push ax
    call OUTPUT_HEX_DIGIT4 ; ouput current di value
    mov al, 0x20
    call OUTPUT_CHR
    pop ax
    push ax
    call OUTPUT_HEX_DIGIT2 ; output current al value
    mov al, 0x20
    call OUTPUT_CHR

    mov si, msg_ERROR
    call OUTPUT_TEXT
    pop ax
    ret


OUTPUT_HEX_DIGIT4:
    ; display a 4 digit hex value from DI register
    pushf
    push ax

    mov ax, di
    mov al, ah
    call OUTPUT_HEX_DIGIT2
    mov ax, di
    call OUTPUT_HEX_DIGIT2

;     mov ax,di
;     mov al,ah
;     shr al,4
;     cmp al,0xa
;     jl .n1_letter
;     add al, 7
; .n1_letter:
;     add al, '0'
;     call OUTPUT_CHR
;     mov ax,di
;     mov al,ah
;     and al,0xf
;     cmp al,0xa
;     jl .n2_letter
;     add al, 7
; .n2_letter:
;     add al, '0'
;     call OUTPUT_CHR
;     mov ax,di
;     shr al,4
;     cmp al,0xa
;     jl .n3_letter
;     add al, 7
; .n3_letter:
;     add al, '0'
;     call OUTPUT_CHR
;     mov ax,di
;     and al,0xf
;     cmp al,0xa
;     jl .n4_letter
;     add al, 7
; .n4_letter:
;     add al, '0'
;     call OUTPUT_CHR
    pop ax
    popf
    ret

OUTPUT_HEX_DIGIT2:
    ; display a 2 digit hex value from AL register
    pushf
    push ax
    shr al,4
    cmp al,0xa
    jl .n1_letter
    add al, 7
.n1_letter:
    add al, '0'
    call OUTPUT_CHR
    pop ax
    push ax
    and al,0xf
    cmp al,0xa
    jl .n2_letter
    add al, 7
.n2_letter:
    add al, '0'
    call OUTPUT_CHR
    pop ax
    popf
    ret

OUTPUT_CRLF:
    mov si, msg_CRLF
    call OUTPUT_TEXT
    ret

OUTPUT_CR:
    push ax
    mov al, 13
    mov ah,0x0e ; 0x0e means 'Write Character in TTY mode'
    int 0x10 ; runs BIOS interrupt 0x10 - Video Services
    pop ax
    ret

OUTPUT_CHR:
; expect AL with chr to output
    push ax
    mov ah,0x0e ; 0x0e means 'Write Character in TTY mode'
    int 0x10 ; runs BIOS interrupt 0x10 - Video Services
    pop ax
    ret

OUTPUT_TEXT:
    ; expect SI with text to output
    pushf
    push ax
.loop_text:
    mov ah,0x0e ; 0x0e means 'Write Character in TTY mode'
    lodsb       ; Load AL from [DS:SI], increment SI
    or al,al
    jz .done
    int 0x10 ; runs BIOS interrupt 0x10 - Video Services
    jmp .loop_text
.done:
    pop ax
    popf
    ret

WAIT_CHR:
    pushf
    push ax
    mov al, '.'
    call OUTPUT_CHR
    mov ah,00h
    int 16h
    cmp al,"q"
    jnz .no_abort
    mov BYTE [sig_abort], 1
.no_abort:
    pop ax
    popf
    ret

fullprog_data  ; This is mandatory for .exe.

msg: 
    db "RAMTEST fÅr EC1834 (c)2023 Mario Goegel", 13, 10
    db 13, 10
    db '1 - Teste gerade Adressen in 4xxxxh', 13, 10
    db '2 - Teste ungerade Adressen in 4xxxxh', 13, 10
    db 13, 10
    db '0 - Ausgang', 13, 10
    db 'Deine Auswahl: ', 0

msg_test1:
    db 'Starte test1...', 13, 10, 0

msg_test2:
    db 'Starte test2...', 13, 10, 0

msg_test1_1:
    db 'TEST 00...', 13, 10, 0

msg_test1_2:
    db 'TEST FF...', 13, 10, 0

msg_test1_3:
    db 'test1 beendet...', 13, 10, 0

msg_bye:
    db 'Bye bye...', 13, 10, 0

msg_CRLF:
    db 13, 10, 0

msg_ERROR:
    db 'FEHLER', 13, 10, 0

cnt_error:
    db 0

sig_abort:
    db 0 ; declare abort condition for tests

tst_byte:
    db 0 ; current test value as byte

ts_word:
    dw 0 ; current test value as word

fullprog_end
