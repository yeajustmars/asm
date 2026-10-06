; ==============================================================================
; Interactive LISP-1 REPL (Read-Eval-Print Loop)
; Pure x86_64 Assembly Entrypoint
; ==============================================================================

default rel

%include "constants.inc"

; Import engine subroutines from lisp.asm
extern _lisp_init
extern _read_sexpr
extern _eval
extern _print_sexpr
extern _print_string
extern _print_char

section .bss
    in_buffer: resb 4096        ; 4KB input buffer for stdin

section .data
    banner_msg: db "==================================================", 10
                db "   Pure x86_64 Assembly McCarthy LISP-1 (1959)   ", 10
                db "==================================================", 10, 10, 0
    prompt_msg: db "lisp> ", 0
    bye_msg:    db 10, "Goodbye!", 10, 0

section .text

global _main

_main:
    push rbp
    mov rbp, rsp

    ; 1. Initialize Lisp Heap and Intern Special Symbols
    call _lisp_init
    cmp rax, 0
    je .init_success

    ; Heap Allocation Failed
    mov rdi, 1
    mov rax, SYS_EXIT
    syscall

.init_success:
    ; 2. Print Welcome Banner
    lea rdi, [rel banner_msg]
    call _print_string

.repl_loop:
    ; 3. Print Prompt "lisp> "
    lea rdi, [rel prompt_msg]
    call _print_string

    ; 4. Read Line from STDIN via sys_read
    mov rax, SYS_READ
    mov rdi, 0                  ; File descriptor 0 = STDIN
    lea rsi, [rel in_buffer]
    mov rdx, 4096
    syscall

    ; Check for EOF (Ctrl+D) or read error (RAX <= 0)
    test rax, rax
    jle .exit_repl

    ; Null-terminate input string at (in_buffer + bytes_read)
    lea rbx, [rel in_buffer]
    mov byte [rbx + rax], 0

    ; 5. READ: Parse S-Expression
    mov rdi, rbx
    call _read_sexpr            ; RAX = Tagged AST, RSI = Next ptr

    ; 6. EVAL: Evaluate AST in empty environment (VAL_NIL)
    mov rdi, rax
    mov rsi, VAL_NIL
    call _eval                  ; RAX = Tagged Evaluation Result

    ; 7. PRINT: Output S-Expression to STDOUT
    mov rdi, rax
    call _print_sexpr

    ; Output trailing newline
    mov rdi, 10
    call _print_char

    jmp .repl_loop

.exit_repl:
    lea rdi, [rel bye_msg]
    call _print_string

    mov rax, SYS_EXIT
    xor rdi, rdi                ; Exit code 0
    syscall
