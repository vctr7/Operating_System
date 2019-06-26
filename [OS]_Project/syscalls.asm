syscall_reboot:
int 19h

syscall_power_off:
mov ax, 5307h
mov cx, 0003h
int 15h
