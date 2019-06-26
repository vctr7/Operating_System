bios_print_string:

load_char_to_al:
lodsb
cmp al, 0
je end_of_string

call bios_print_char
jmp short load_char_to_al

end_of_string:
ret

bios_print_char:
mov ah, 0Eh
int 10h
ret

bios_print_newline:
mov al, 13
call bios_print_char
mov al, 10
call bios_print_char
ret

bios_wait_for_key:
mov ax, 0
int 16h
ret

bios_check_for_key:
mov ax, 0
mov ah, 1
int 16h

jz nokey_pressed

mov ax, 0
int 16h

ret

nokey_pressed:
mov ax, 0
ret

bios_move_cursor:
mov bh, 0
mov ah, 2
int 10h

ret

bios_get_cursor_pos:
mov bh, 0
mov ah, 3
int 10h

ret

bios_clear_screen:
mov dx, 0
call bios_move_cursor

mov ah, 6
mov al, 0
mov bh, 7
mov cx, 0
mov dh, 24
mov dl, 79
int 10h
ret
