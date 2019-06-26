kernel_init:
cli
mov ax, StackSegmentStart
mov ss, ax
mov sp, StackPointerStart
sti

cld

mov ax, DataSegmentStart
mov ds, ax
mov es, ax
mov fs, ax
mov gs, ax

kernel_main:
call print_welcome_messages
call bios_print_newline

kernel_main_loop:
call bios_print_newline
call print_menu
call bios_print_newline
call print_prompt
call bios_wait_for_key
mov word [savedWord], ax
call bios_print_char
call bios_print_newline
call perform_menu_action
jmp kernel_main_loop

print_welcome_messages:
mov si, welcome_msg
call bios_print_string
mov si, written_by_msg
call bios_print_string
ret

print_menu:
mov si, menu1
call bios_print_string
mov si, menu2
call bios_print_string
mov si, menu3
call bios_print_string
mov si, menu4
call bios_print_string
mov si, menu5
call bios_print_string
ret

print_prompt:
mov si, prompt_string
call bios_print_string
ret

perform_menu_action:
mov word ax, [savedWord]

cmp al, '1'
je print_hello

cmp al, '2'
je bios_clear_screen

cmp al, '3'
je syscall_reboot

cmp al, '4'
je syscall_power_off

cmp al, '5'
je print_os

ret

print_hello:
call bios_print_newline
mov si, hello_msg
call bios_print_string
ret

print_os:
call bios_print_newline
mov si, os_msg
call bios_print_string
ret
