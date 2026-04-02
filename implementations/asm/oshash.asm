; OpenSubtitles Hash (OSHash) - x86-64 Linux NASM implementation.
; Algorithm: file_size + sum_uint64_le(first_64KB) + sum_uint64_le(last_64KB)
; Build: nasm -f elf64 oshash.asm && ld -o oshash oshash.o
; Usage: ./oshash <file>

section .data
    hex_chars: db "0123456789abcdef"
    newline:   db 10
    err_usage: db "Usage: oshash <file>", 10
    err_ulen   equ $ - err_usage
    err_open:  db "Error opening file", 10
    err_olen   equ $ - err_open

section .bss
    buf:       resb 65536          ; 64KB read buffer
    hash_str:  resb 16             ; hex output string
    stat_buf:  resb 144            ; stat struct

section .text
    global _start

_start:
    ; Check argc >= 2
    mov rdi, [rsp]                 ; argc
    cmp rdi, 2
    jl .usage_error

    ; Open file (argv[1])
    mov rdi, [rsp + 16]            ; argv[1]
    mov rsi, 0                     ; O_RDONLY
    xor rdx, rdx
    mov rax, 2                     ; sys_open
    syscall
    test rax, rax
    js .open_error
    mov r12, rax                   ; r12 = fd

    ; fstat to get file size
    mov rdi, r12
    lea rsi, [stat_buf]
    mov rax, 5                     ; sys_fstat
    syscall
    mov r13, [stat_buf + 48]       ; r13 = file size (st_size at offset 48)

    ; hash = file_size
    mov r14, r13                   ; r14 = hash

    ; Read first 64KB
    mov rdi, r12                   ; fd
    lea rsi, [buf]                 ; buffer
    mov rdx, 65536                 ; count
    mov rax, 0                     ; sys_read
    syscall

    ; Sum first 64KB as uint64 LE
    lea rsi, [buf]
    mov rcx, 8192                  ; 65536 / 8
.sum_head:
    add r14, [rsi]
    add rsi, 8
    dec rcx
    jnz .sum_head

    ; Seek to (filesize - 64KB)
    mov rdi, r12                   ; fd
    mov rsi, r13
    sub rsi, 65536                 ; offset = fsize - 64K
    mov rdx, 0                     ; SEEK_SET
    mov rax, 8                     ; sys_lseek
    syscall

    ; Read last 64KB
    mov rdi, r12
    lea rsi, [buf]
    mov rdx, 65536
    mov rax, 0                     ; sys_read
    syscall

    ; Sum last 64KB as uint64 LE
    lea rsi, [buf]
    mov rcx, 8192
.sum_tail:
    add r14, [rsi]
    add rsi, 8
    dec rcx
    jnz .sum_tail

    ; Close file
    mov rdi, r12
    mov rax, 3                     ; sys_close
    syscall

    ; Convert r14 (hash) to hex string
    mov rax, r14
    lea rdi, [hash_str + 15]       ; start from end
    mov rcx, 16
.hex_loop:
    mov rdx, rax
    and rdx, 0xF
    lea rsi, [hex_chars]
    mov dl, [rsi + rdx]
    mov [rdi], dl
    shr rax, 4
    dec rdi
    dec rcx
    jnz .hex_loop

    ; Write hex string + newline
    mov rdi, 1                     ; stdout
    lea rsi, [hash_str]
    mov rdx, 16
    mov rax, 1                     ; sys_write
    syscall
    mov rdi, 1
    lea rsi, [newline]
    mov rdx, 1
    mov rax, 1
    syscall

    ; Exit 0
    xor rdi, rdi
    mov rax, 60                    ; sys_exit
    syscall

.usage_error:
    mov rdi, 2
    lea rsi, [err_usage]
    mov rdx, err_ulen
    mov rax, 1
    syscall
    mov rdi, 1
    mov rax, 60
    syscall

.open_error:
    mov rdi, 2
    lea rsi, [err_open]
    mov rdx, err_olen
    mov rax, 1
    syscall
    mov rdi, 1
    mov rax, 60
    syscall
