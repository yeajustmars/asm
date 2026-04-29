default rel                       ; Use position-independent code (PIE) required by macOS

; macOS syscall numbers are offset by 0x2000000 (BSD class)
%define SYS_WRITE 0x2000004
%define SYS_EXIT 0x2000001
%define STDOUT 1

global _main

section .data
    ; Our input strings, null-terminated
    str1 db "Hello, ", 0
    str2 db "bare metal ", 0
    str3 db "x86_64 Assembly ", 0
    str4 db "on macOS!", 10, 0   ; 10 is the newline character

    ; The "variable number of strings" passed as an array of pointers.
    ; The array MUST be terminated with a 0 (NULL pointer).
    str_array dq str1, str2, str3, str4, 0

section .bss
  ; Static buffer to hold the concatenated result (1024 bytes)
  out_buffer resb 1024

section .text

; -----------------------------------------------------------------------------
; _main: Entry point
; -----------------------------------------------------------------------------
_main:
  ; 1. Concatenate strings
  lea rdi, [str_array]            ; Arg 1: pointer to array of string pointers
  lea rsi, [out_buffer]           ; Arg 2: pointer to destination buffer
  call concat_strings

  ; 2. Print the concatenated string
  lea rdi, [out_buffer]             ; Arg 1: pointer to the string to print
  call print_string

  ; 3. Exit gracdfully
  mov rax, SYS_EXIT               ; syscall: exit
  xor rdi, rdi                    ; exit code 0
  syscall

; -----------------------------------------------------------------------------
; concat_strings: Concatenates a null-pointer-terminated array of strings
; Input:  rdi = pointer to an array of 64-bit string pointers (null-terminated)
;         rsi = pointer to destination buffer
; Output: rsi buffer is populated and null-terminated.
; -----------------------------------------------------------------------------
concat_strings:
  ; Save callee-saved registers per System V ABI
  push rbx
  push r12
  push r13

  mov r12, rdi                    ; r12 = current pointer in the array
  mov r13, rsi                    ; r13 = current write position in the destination buffer

.next_string:
  mov rbx, [r12]                  ; Load the string pointer from the array
  test rbx, rbx                   ; Is the pointer NULL (0)?
  jz .done                        ; If yes, we've processed all strings

.copy_char:
  mov al, [rbx]                   ; Load the string pointer from the array
  test al, al                     ; Is it the NULL terminator ()?
  jz .string_done                 ; If yes, this string is finished

  mov [r13], al                   ; Write the byte to our destination buffer
  inc rbx                         ; Advance source pointer
  inc r13                         ; Advance destination pointer
  jmp .copy_char                  ; Loop for next character

.string_done:
  add r12, 8                      ; Advance array pointer by 8 bytes (64-bit pointer size)
  jmp .next_string                ; Grab the next string pointer

.done:
  mov byte [r13], 0               ; Add final NULL terminator to the concatenated string

  ; Restore callee-saved registers
  pop r13
  pop r12
  pop rbx
  ret

; -----------------------------------------------------------------------------
; print_string: Prints a null-terminated string to STDOUT
; Input: rdi = pointer to string
; -----------------------------------------------------------------------------
print_string:
  push r12
  mov r12, rdi                    ; Save original string pointer

  ; Call our helper to get the length
  call strlen                     ; length is returned in RAX

  ; Set up the write syscall
  mov rdx, rax                    ; Arg 3: length of string
  mov rsi, r12                    ; Arg 2: pointer to string buffer
  mov rdi, STDOUT                 ; Arg 1: file descriptor (1 = stdout)
  mov rax, SYS_WRITE              ; Syscall number for write
  syscall

  pop r12
  ret

; -----------------------------------------------------------------------------
; strlen: Calculates the length of a null-terminated string
; Input:  rdi = pointer to string
; Output: rax = length of string
; -----------------------------------------------------------------------------
strlen:
  xor rax, rax                    ; length = 0

.strlen_loop:
  cmp byte [rdi + rax], 0         ; Check if current char is NULL terminator
  je .strlen_done
  inc rax                         ; Increment length
  jmp .strlen_loop

.strlen_done:
  ret
