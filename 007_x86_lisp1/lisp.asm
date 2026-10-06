; ==============================================================================
; Core LISP-1 Engine Subroutines
; Pure x86_64 Assembly implementation of Memory, Symbols, Reader, Printer, & EVAL
; ==============================================================================

default rel

%include "constants.inc"

section .bss
    heap_base:    resq 1       ; Base pointer returned by sys_mmap
    heap_ptr:     resq 1       ; Current bump allocation pointer
    symbol_table: resq 1       ; Head pointer of singly linked symbol table

    ; Special Form Symbol Registers
    sym_quote:    resq 1
    sym_cond:     resq 1
    sym_lambda:   resq 1
    sym_define:   resq 1

section .data
    str_quote_name: db "QUOTE", 0
    str_cond_name:  db "COND", 0
    str_lambda_name:db "LAMBDA", 0
    str_define_name:db "DEFINE", 0

    str_sym_car:    db "CAR", 0
    str_sym_cdr:    db "CDR", 0
    str_sym_cons:   db "CONS", 0
    str_sym_eq:     db "EQ", 0
    str_sym_atom:   db "ATOM", 0
    str_sym_add:    db "+", 0
    str_sym_sub:    db "-", 0
    str_sym_mul:    db "*", 0

    str_nil_disp:   db "NIL", 0
    str_true_disp:  db "T", 0
    str_prim_disp:  db "#<PRIMITIVE>", 0

section .text

; Core Heap Operations
global _lisp_init
global _lisp_alloc
global _lisp_cons
global _lisp_car
global _lisp_cdr
global _int_to_fixnum
global _fixnum_to_int

; Symbol Operations
global _intern_symbol
global _symbol_name
global _symbol_val
global _set_symbol_val

; Reader & Printer Operations
global _read_sexpr
global _sprint_int
global _sprint_sexpr
global _print_sexpr
global _print_string
global _print_char

; Primitives & Environment
global _prim_car
global _prim_cdr
global _prim_cons
global _prim_eq
global _prim_atom
global _prim_add
global _prim_sub
global _prim_mul
global _assoc

; Universal EVAL / APPLY Engine
global _pairlis
global _evlis
global _eval
global _apply

; ------------------------------------------------------------------------------
; Phase 1: Memory Arena & Tagging Operations
; ------------------------------------------------------------------------------

_lisp_alloc:
    push rbp
    mov rbp, rsp

    add rdi, 15
    and rdi, -16

    mov rax, [rel heap_ptr]
    mov rdx, rax
    add rdx, rdi

    mov rcx, [rel heap_base]
    add rcx, HEAP_SIZE
    cmp rdx, rcx
    jae .oom

    mov [rel heap_ptr], rdx
    pop rbp
    ret

.oom:
    xor rax, rax
    pop rbp
    ret

_lisp_cons:
    push rbp
    mov rbp, rsp
    push rbx
    push r12

    mov rbx, rdi
    mov r12, rsi

    mov rdi, 16
    call _lisp_alloc
    test rax, rax
    jz .cons_fail

    mov [rax], rbx
    mov [rax + 8], r12

.cons_fail:
    pop r12
    pop rbx
    pop rbp
    ret

_lisp_car:
    mov rax, rdi
    and rax, ~TAG_MASK
    mov rax, [rax]
    ret

_lisp_cdr:
    mov rax, rdi
    and rax, ~TAG_MASK
    mov rax, [rax + 8]
    ret

_int_to_fixnum:
    mov rax, rdi
    shl rax, 3
    or  rax, TAG_FIXNUM
    ret

_fixnum_to_int:
    mov rax, rdi
    sar rax, 3
    ret

; ------------------------------------------------------------------------------
; String & Printing Utilities
; ------------------------------------------------------------------------------
_print_string:
    push rbp
    mov rbp, rsp
    push rbx

    mov rbx, rdi
    xor rdx, rdx

.strlen_loop:
    cmp byte [rbx + rdx], 0
    je .strlen_done
    inc rdx
    jmp .strlen_loop

.strlen_done:
    mov rax, SYS_WRITE
    mov rdi, STDOUT
    mov rsi, rbx
    syscall

    pop rbx
    pop rbp
    ret

_print_char:
    push rbp
    mov rbp, rsp
    push rdi

    mov rax, SYS_WRITE
    mov rdi, STDOUT
    mov rsi, rsp
    mov rdx, 1
    syscall

    pop rdi
    pop rbp
    ret

; ------------------------------------------------------------------------------
; Symbol Subroutines
; ------------------------------------------------------------------------------
_streq:
    push rbp
    mov rbp, rsp
    push rbx

.compare_loop:
    mov al, [rdi]
    mov bl, [rsi]
    cmp al, bl
    jne .not_equal
    test al, al
    jz .equal
    inc rdi
    inc rsi
    jmp .compare_loop

.equal:
    mov rax, 1
    pop rbx
    pop rbp
    ret

.not_equal:
    xor rax, rax
    pop rbx
    pop rbp
    ret

_intern_symbol:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13

    mov rbx, rdi
    mov r12, [rel symbol_table]

.search_loop:
    test r12, r12
    jz .not_found

    mov rdi, rbx
    mov rsi, [r12 + 8]
    call _streq
    cmp rax, 1
    je .found

    mov r12, [r12]
    jmp .search_loop

.found:
    mov rax, r12
    or  rax, TAG_SYMBOL
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

.not_found:
    mov rdi, rbx
    xor rcx, rcx
.strlen_loop:
    cmp byte [rdi + rcx], 0
    je .strlen_done
    inc rcx
    jmp .strlen_loop
.strlen_done:
    inc rcx
    mov r13, rcx

    mov rdi, r13
    call _lisp_alloc
    mov r12, rax

    xor rcx, rcx
.copy_loop:
    mov al, [rbx + rcx]
    mov [r12 + rcx], al
    inc rcx
    cmp rcx, r13
    jne .copy_loop

    mov rdi, 24
    call _lisp_alloc
    mov rbx, rax

    mov rcx, [rel symbol_table]
    mov [rbx], rcx
    mov [rbx + 8], r12
    mov qword [rbx + 16], VAL_NIL

    mov [rel symbol_table], rbx

    mov rax, rbx
    or  rax, TAG_SYMBOL
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

_symbol_name:
    mov rax, rdi
    and rax, ~TAG_MASK
    mov rax, [rax + 8]
    ret

_symbol_val:
    mov rax, rdi
    and rax, ~TAG_MASK
    mov rax, [rax + 16]
    ret

_set_symbol_val:
    mov rax, rdi
    and rax, ~TAG_MASK
    mov [rax + 16], rsi
    ret

; ------------------------------------------------------------------------------
; S-Expression Reader Subroutines
; ------------------------------------------------------------------------------
_skip_whitespace:
    mov al, [rdi]
    cmp al, ' '
    je .advance
    cmp al, 9
    je .advance
    cmp al, 10
    je .advance
    cmp al, 13
    je .advance
    ret
.advance:
    inc rdi
    jmp _skip_whitespace

_is_delimiter:
    test al, al
    jz .is_delim
    cmp al, ' '
    je .is_delim
    cmp al, 9
    je .is_delim
    cmp al, 10
    je .is_delim
    cmp al, 13
    je .is_delim
    cmp al, '('
    je .is_delim
    cmp al, ')'
    je .is_delim
    cmp al, "'"
    je .is_delim
    cmp al, 0                   ; Set ZF=0 without mutating AL
    ret
.is_delim:
    xor al, al                  ; Set ZF=1
    ret

_is_nil_token:
    mov al, [rdi]
    cmp al, 'N'
    je .check_upper
    cmp al, 'n'
    je .check_lower
    xor rax, rax
    ret

.check_upper:
    cmp byte [rdi + 1], 'I'
    jne .no
    cmp byte [rdi + 2], 'L'
    jne .no
    cmp byte [rdi + 3], 0
    jne .no
    mov rax, 1
    ret

.check_lower:
    cmp byte [rdi + 1], 'i'
    jne .no
    cmp byte [rdi + 2], 'l'
    jne .no
    cmp byte [rdi + 3], 0
    jne .no
    mov rax, 1
    ret

.no:
    xor rax, rax
    ret

_parse_number:
    push rbp
    mov rbp, rsp
    push rbx
    push r12

    mov rbx, rdi
    xor r12, r12
    xor rax, rax

    cmp byte [rbx], '-'
    jne .digit_loop
    mov r12, 1
    inc rbx

.digit_loop:
    mov cl, [rbx]
    cmp cl, '0'
    jb .done
    cmp cl, '9'
    ja .done

    sub cl, '0'
    movzx rcx, cl

    imul rax, 10
    add rax, rcx

    inc rbx
    jmp .digit_loop

.done:
    test r12, r12
    jz .pos
    neg rax

.pos:
    mov rdi, rax
    call _int_to_fixnum
    mov rsi, rbx
    pop r12
    pop rbx
    pop rbp
    ret

_parse_symbol:
    push rbp
    mov rbp, rsp
    sub rsp, 128
    push rbx
    push r12

    mov rbx, rdi
    lea r12, [rbp - 128]
    xor rcx, rcx

.copy_loop:
    mov al, [rbx + rcx]
    call _is_delimiter
    jz .token_end

    mov [r12 + rcx], al
    inc rcx
    cmp rcx, 127
    jl .copy_loop

.token_end:
    mov byte [r12 + rcx], 0
    add rbx, rcx

    mov rdi, r12
    call _is_nil_token
    test rax, rax
    jnz .return_nil

    mov rdi, r12
    call _intern_symbol
    mov rsi, rbx
    pop r12
    pop rbx
    mov rsp, rbp
    pop rbp
    ret

.return_nil:
    mov rax, VAL_NIL
    mov rsi, rbx
    pop r12
    pop rbx
    mov rsp, rbp
    pop rbp
    ret

_read_list:
    push rbp
    mov rbp, rsp
    push rbx
    push r12

    call _skip_whitespace
    mov al, [rdi]
    cmp al, ')'
    je .empty_list

    cmp al, '.'
    jne .normal_element

    mov cl, [rdi + 1]
    mov al, cl
    call _is_delimiter
    jnz .normal_element

    inc rdi
    call _read_sexpr
    mov r12, rax

    mov rdi, rsi
    call _skip_whitespace
    cmp byte [rdi], ')'
    jne .empty_list
    inc rdi

    mov rax, r12
    mov rsi, rdi
    pop r12
    pop rbx
    pop rbp
    ret

.normal_element:
    call _read_sexpr
    mov rbx, rax
    mov rdi, rsi

    call _read_list
    mov r12, rsi

    mov rdi, rbx
    mov rsi, rax
    call _lisp_cons

    mov rsi, r12
    pop r12
    pop rbx
    pop rbp
    ret

.empty_list:
    inc rdi
    mov rax, VAL_NIL
    mov rsi, rdi
    pop r12
    pop rbx
    pop rbp
    ret

_read_sexpr:
    push rbp
    mov rbp, rsp
    push rbx
    push r12

    call _skip_whitespace
    mov al, [rdi]
    test al, al
    jz .eof

    cmp al, '('
    je .parse_list

    cmp al, "'"
    je .parse_quote

    cmp al, '-'
    je .check_minus

    cmp al, '0'
    jb .parse_symbol
    cmp al, '9'
    jbe .parse_number

.parse_symbol:
    call _parse_symbol
    pop r12
    pop rbx
    pop rbp
    ret

.parse_number:
    call _parse_number
    pop r12
    pop rbx
    pop rbp
    ret

.check_minus:
    mov cl, [rdi + 1]
    cmp cl, '0'
    jb .parse_symbol
    cmp cl, '9'
    jbe .parse_number
    jmp .parse_symbol

.parse_list:
    inc rdi
    call _read_list
    pop r12
    pop rbx
    pop rbp
    ret

.parse_quote:
    inc rdi
    call _read_sexpr
    mov rbx, rax
    mov r12, rsi

    lea rdi, [rel str_quote_name]
    call _intern_symbol
    mov rdx, rax

    mov rdi, rbx
    mov rsi, VAL_NIL
    push rdx
    call _lisp_cons
    mov rsi, rax
    pop rdi
    call _lisp_cons

    mov rsi, r12
    pop r12
    pop rbx
    pop rbp
    ret

.eof:
    mov rax, VAL_NIL
    mov rsi, rdi
    pop r12
    pop rbx
    pop rbp
    ret

; ------------------------------------------------------------------------------
; S-Expression Printer Subroutines
; ------------------------------------------------------------------------------
_sprint_int:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13

    mov rax, rdi
    mov rbx, rsi

    test rax, rax
    jns .positive

    mov byte [rbx], '-'
    inc rbx
    neg rax

.positive:
    mov r12, rsp
    mov r13, 10

.digit_loop:
    xor rdx, rdx
    div r13
    add dl, '0'
    dec rsp
    mov [rsp], dl
    test rax, rax
    jnz .digit_loop

.write_digits:
    cmp rsp, r12
    je .done
    mov al, [rsp]
    mov [rbx], al
    inc rbx
    inc rsp
    jmp .write_digits

.done:
    mov byte [rbx], 0
    mov rax, rbx

    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

_sprint_sexpr:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13

    mov rbx, rdi
    mov r12, rsi

    cmp rbx, VAL_NIL
    je .print_nil

    cmp rbx, VAL_TRUE
    je .print_true

    mov rcx, rbx
    and rcx, TAG_MASK

    cmp rcx, TAG_FIXNUM
    je .print_fixnum

    cmp rcx, TAG_SYMBOL
    je .print_symbol

    cmp rcx, TAG_CONS
    je .print_cons

    cmp rcx, TAG_PRIM
    je .print_prim

    mov byte [r12], '?'
    mov byte [r12 + 1], 0
    lea rax, [r12 + 1]
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

.print_nil:
    lea rsi, [rel str_nil_disp]
    jmp .copy_str_and_exit

.print_true:
    lea rsi, [rel str_true_disp]
    jmp .copy_str_and_exit

.print_prim:
    lea rsi, [rel str_prim_disp]
    jmp .copy_str_and_exit

.print_symbol:
    mov rdi, rbx
    call _symbol_name
    mov rsi, rax
    jmp .copy_str_and_exit

.copy_str_and_exit:
.copy_loop:
    mov al, [rsi]
    mov [r12], al
    test al, al
    jz .str_copied
    inc rsi
    inc r12
    jmp .copy_loop
.str_copied:
    mov rax, r12
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

.print_fixnum:
    mov rdi, rbx
    call _fixnum_to_int
    mov rdi, rax
    mov rsi, r12
    call _sprint_int
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

.print_cons:
    mov byte [r12], '('
    inc r12

.list_loop:
    mov rdi, rbx
    call _lisp_car
    mov rdi, rax
    mov rsi, r12
    call _sprint_sexpr
    mov r12, rax

    mov rdi, rbx
    call _lisp_cdr
    mov r13, rax

    cmp r13, VAL_NIL
    je .close_list

    mov rcx, r13
    and rcx, TAG_MASK
    cmp rcx, TAG_CONS
    je .next_element

    mov byte [r12], ' '
    mov byte [r12 + 1], '.'
    mov byte [r12 + 2], ' '
    add r12, 3

    mov rdi, r13
    mov rsi, r12
    call _sprint_sexpr
    mov r12, rax

.close_list:
    mov byte [r12], ')'
    inc r12
    mov byte [r12], 0
    mov rax, r12
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

.next_element:
    mov byte [r12], ' '
    inc r12
    mov rbx, r13
    jmp .list_loop

_print_sexpr:
    push rbp
    mov rbp, rsp
    sub rsp, 1024

    lea rsi, [rbp - 1024]
    call _sprint_sexpr

    lea rdi, [rbp - 1024]
    call _print_string

    mov rsp, rbp
    pop rbp
    ret

; ------------------------------------------------------------------------------
; Phase 4: McCarthy Primitives & Environment Lookup
; ------------------------------------------------------------------------------
_prim_car:
    push rbp
    mov rbp, rsp
    call _lisp_car
    mov rdi, rax
    call _lisp_car
    pop rbp
    ret

_prim_cdr:
    push rbp
    mov rbp, rsp
    call _lisp_car
    mov rdi, rax
    call _lisp_cdr
    pop rbp
    ret

_prim_cons:
    push rbp
    mov rbp, rsp
    push rbx
    push r12

    mov rbx, rdi
    mov rdi, rbx
    call _lisp_car
    mov r12, rax

    mov rdi, rbx
    call _lisp_cdr
    mov rdi, rax
    call _lisp_car

    mov rdi, r12
    mov rsi, rax
    call _lisp_cons

    pop r12
    pop rbx
    pop rbp
    ret

_prim_eq:
    push rbp
    mov rbp, rsp
    push rbx
    push r12

    mov rbx, rdi
    mov rdi, rbx
    call _lisp_car
    mov r12, rax

    mov rdi, rbx
    call _lisp_cdr
    mov rdi, rax
    call _lisp_car

    cmp r12, rax
    je .equal

    mov rax, VAL_NIL
    pop r12
    pop rbx
    pop rbp
    ret

.equal:
    mov rax, VAL_TRUE
    pop r12
    pop rbx
    pop rbp
    ret

_prim_atom:
    push rbp
    mov rbp, rsp

    call _lisp_car

    cmp rax, VAL_NIL
    je .is_atom

    mov rcx, rax
    and rcx, TAG_MASK
    cmp rcx, TAG_CONS
    je .not_atom

.is_atom:
    mov rax, VAL_TRUE
    pop rbp
    ret

.not_atom:
    mov rax, VAL_NIL
    pop rbp
    ret

_prim_add:
    push rbp
    mov rbp, rsp
    push rbx
    push r12

    mov rbx, rdi
    mov rdi, rbx
    call _lisp_car
    mov r12, rax

    mov rdi, rbx
    call _lisp_cdr
    mov rdi, rax
    call _lisp_car

    add rax, r12
    sub rax, TAG_FIXNUM

    pop r12
    pop rbx
    pop rbp
    ret

_prim_sub:
    push rbp
    mov rbp, rsp
    push rbx
    push r12

    mov rbx, rdi
    mov rdi, rbx
    call _lisp_car
    mov r12, rax

    mov rdi, rbx
    call _lisp_cdr
    mov rdi, rax
    call _lisp_car

    sub r12, rax
    add r12, TAG_FIXNUM
    mov rax, r12

    pop r12
    pop rbx
    pop rbp
    ret

_prim_mul:
    push rbp
    mov rbp, rsp
    push rbx
    push r12

    mov rbx, rdi
    mov rdi, rbx
    call _lisp_car
    call _fixnum_to_int
    mov r12, rax

    mov rdi, rbx
    call _lisp_cdr
    mov rdi, rax
    call _lisp_car
    call _fixnum_to_int

    imul rax, r12
    mov rdi, rax
    call _int_to_fixnum

    pop r12
    pop rbx
    pop rbp
    ret

_assoc:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13

    mov rbx, rdi
    mov r12, rsi

.loop:
    cmp r12, VAL_NIL
    je .not_found

    mov rdi, r12
    call _lisp_car
    mov r13, rax

    mov rdi, r13
    call _lisp_car

    cmp rax, rbx
    je .found

    mov rdi, r12
    call _lisp_cdr
    mov r12, rax
    jmp .loop

.found:
    mov rax, r13
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

.not_found:
    mov rax, VAL_NIL
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; ------------------------------------------------------------------------------
; _lisp_init
; Requests a 64MB memory region via sys_mmap and initializes special symbols.
; Placed after symbol and primitive function definitions for backward resolution.
; ------------------------------------------------------------------------------
_lisp_init:
    push rbp
    mov rbp, rsp

    mov rdi, 0                  ; addr = NULL
    mov rsi, HEAP_SIZE          ; len = 64 MB
    mov rdx, PROT_READ | PROT_WRITE ; prot
    mov r10, MAP_PRIVATE | MAP_ANON ; flags
    mov r8, -1                  ; fd = -1
    mov r9, 0                   ; offset = 0
    mov rax, SYS_MMAP
    syscall

    jc .mmap_failed
    test rax, rax
    js .mmap_failed

    mov [rel heap_base], rax
    mov [rel heap_ptr], rax

    ; Intern Special Forms
    lea rdi, [rel str_quote_name]
    call _intern_symbol
    mov [rel sym_quote], rax

    lea rdi, [rel str_cond_name]
    call _intern_symbol
    mov [rel sym_cond], rax

    lea rdi, [rel str_lambda_name]
    call _intern_symbol
    mov [rel sym_lambda], rax

    lea rdi, [rel str_define_name]
    call _intern_symbol
    mov [rel sym_define], rax

    ; Bind Primitives to Global Symbol Value Cells
    lea rdi, [rel str_sym_car]
    call _intern_symbol
    mov rdi, rax
    lea rsi, [rel _prim_car]
    or rsi, TAG_PRIM
    call _set_symbol_val

    lea rdi, [rel str_sym_cdr]
    call _intern_symbol
    mov rdi, rax
    lea rsi, [rel _prim_cdr]
    or rsi, TAG_PRIM
    call _set_symbol_val

    lea rdi, [rel str_sym_cons]
    call _intern_symbol
    mov rdi, rax
    lea rsi, [rel _prim_cons]
    or rsi, TAG_PRIM
    call _set_symbol_val

    lea rdi, [rel str_sym_eq]
    call _intern_symbol
    mov rdi, rax
    lea rsi, [rel _prim_eq]
    or rsi, TAG_PRIM
    call _set_symbol_val

    lea rdi, [rel str_sym_atom]
    call _intern_symbol
    mov rdi, rax
    lea rsi, [rel _prim_atom]
    or rsi, TAG_PRIM
    call _set_symbol_val

    lea rdi, [rel str_sym_add]
    call _intern_symbol
    mov rdi, rax
    lea rsi, [rel _prim_add]
    or rsi, TAG_PRIM
    call _set_symbol_val

    lea rdi, [rel str_sym_sub]
    call _intern_symbol
    mov rdi, rax
    lea rsi, [rel _prim_sub]
    or rsi, TAG_PRIM
    call _set_symbol_val

    lea rdi, [rel str_sym_mul]
    call _intern_symbol
    mov rdi, rax
    lea rsi, [rel _prim_mul]
    or rsi, TAG_PRIM
    call _set_symbol_val

    xor rax, rax                ; Return 0 for success
    pop rbp
    ret

.mmap_failed:
    mov rax, -1
    pop rbp
    ret

; ------------------------------------------------------------------------------
; Phase 5: Universal EVAL / APPLY Engine
; ------------------------------------------------------------------------------

; ------------------------------------------------------------------------------
; _pairlis
; Extends an A-list environment by pairing keys and values.
; Inputs: RDI = Keys list (k1 k2 ...)
;         RSI = Values list (v1 v2 ...)
;         RDX = Base Environment A-list
; Output: RAX = Extended Environment A-list ((k1 . v1) (k2 . v2) ... . env)
; ------------------------------------------------------------------------------
_pairlis:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14

    mov rbx, rdi                ; RBX = keys
    mov r12, rsi                ; R12 = vals
    mov r13, rdx                ; R13 = env

.loop:
    cmp rbx, VAL_NIL
    je .done

    mov rdi, rbx
    call _lisp_car
    mov r14, rax                ; R14 = key

    mov rdi, r12
    call _lisp_car              ; RAX = val

    mov rdi, r14
    mov rsi, rax
    call _lisp_cons             ; RAX = (key . val)

    mov rdi, rax
    mov rsi, r13
    call _lisp_cons
    mov r13, rax                ; R13 = updated env

    mov rdi, rbx
    call _lisp_cdr
    mov rbx, rax

    mov rdi, r12
    call _lisp_cdr
    mov r12, rax

    jmp .loop

.done:
    mov rax, r13
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; ------------------------------------------------------------------------------
; _evlis
; Evaluates a list of argument expressions recursively.
; Inputs: RDI = List of argument expressions (e1 e2 ...)
;         RSI = Environment A-list
; Output: RAX = List of evaluated argument values (v1 v2 ...)
; ------------------------------------------------------------------------------
_evlis:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13

    mov rbx, rdi
    mov r12, rsi

    cmp rbx, VAL_NIL
    je .empty

    mov rdi, rbx
    call _lisp_car
    mov rdi, rax
    mov rsi, r12
    call _eval
    mov r13, rax                ; R13 = evaled CAR

    mov rdi, rbx
    call _lisp_cdr
    mov rdi, rax
    mov rsi, r12
    call _evlis                 ; RAX = evaled CDR

    mov rdi, r13
    mov rsi, rax
    call _lisp_cons
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

.empty:
    mov rax, VAL_NIL
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; ------------------------------------------------------------------------------
; _eval
; McCarthy 1959 Universal EVAL Evaluator
; Inputs: RDI = Tagged Lisp Expression
;         RSI = Tagged A-list Environment
; Output: RAX = Tagged Evaluation Result
; ------------------------------------------------------------------------------
_eval:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13

    mov rbx, rdi                ; RBX = expr
    mov r12, rsi                ; R12 = env

.eval_loop:
    cmp rbx, VAL_NIL
    je .return_self
    cmp rbx, VAL_TRUE
    je .return_self

    mov rcx, rbx
    and rcx, TAG_MASK

    cmp rcx, TAG_FIXNUM
    je .return_self

    cmp rcx, TAG_PRIM
    je .return_self

    cmp rcx, TAG_SYMBOL
    je .eval_symbol

    cmp rcx, TAG_CONS
    je .eval_cons

.return_self:
    mov rax, rbx
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

.eval_symbol:
    mov rdi, rbx
    mov rsi, r12
    call _assoc
    cmp rax, VAL_NIL
    jne .symbol_found_in_env

    mov rdi, rbx
    call _symbol_val
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

.symbol_found_in_env:
    mov rdi, rax
    call _lisp_cdr
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

.eval_cons:
    mov rdi, rbx
    call _lisp_car
    mov r13, rax                ; R13 = fn_expr

    mov rdi, rbx
    call _lisp_cdr
    mov rbx, rax                ; RBX = args_expr

    ; Check Special Forms
    cmp r13, [rel sym_quote]
    je .special_quote

    cmp r13, [rel sym_cond]
    je .special_cond

    cmp r13, [rel sym_lambda]
    je .special_lambda

    cmp r13, [rel sym_define]
    je .special_define

    ; Ordinary Function Application
    mov rdi, r13
    mov rsi, r12
    call _eval
    mov r13, rax                ; R13 = evaluated function

    mov rdi, rbx
    mov rsi, r12
    call _evlis
    mov rsi, rax                ; RSI = evaluated arguments

    mov rdi, r13
    mov rdx, r12
    call _apply
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

.special_quote:
    mov rdi, rbx
    call _lisp_car
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

.special_lambda:
    mov rdi, [rel sym_lambda]
    mov rsi, rbx
    call _lisp_cons
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

.special_define:
    mov rdi, rbx
    call _lisp_car
    mov r13, rax                ; R13 = variable symbol

    mov rdi, rbx
    call _lisp_cdr
    mov rdi, rax
    call _lisp_car

    mov rdi, rax
    mov rsi, r12
    call _eval

    mov rdi, r13
    mov rsi, rax
    call _set_symbol_val

    mov rax, r13
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

.special_cond:
.cond_loop:
    cmp rbx, VAL_NIL
    je .cond_nil

    mov rdi, rbx
    call _lisp_car
    mov r13, rax                ; R13 = clause (p_i e_i)

    mov rdi, rbx
    call _lisp_cdr
    mov rbx, rax                ; Advance RBX to next clause

    mov rdi, r13
    call _lisp_car
    mov rdi, rax
    mov rsi, r12
    call _eval                  ; Evaluate predicate p_i

    cmp rax, VAL_NIL
    je .cond_loop               ; If NIL, try next clause

    ; Predicate succeeded -> TCO into e_i
    mov rdi, r13
    call _lisp_cdr
    mov rdi, rax
    call _lisp_car
    mov rbx, rax                ; RBX = e_i
    jmp .eval_loop              ; Tail-Call Optimization loop

.cond_nil:
    mov rax, VAL_NIL
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; ------------------------------------------------------------------------------
; _apply
; Applies a primitive or user-defined LAMBDA function to evaluated arguments.
; Inputs: RDI = Tagged Function Value
;         RSI = Tagged Evaluated Arguments List
;         RDX = Tagged Environment A-list
; Output: RAX = Tagged Application Result
; ------------------------------------------------------------------------------
_apply:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13

    mov rbx, rdi                ; RBX = fn_val
    mov r12, rsi                ; R12 = evaled_args
    mov r13, rdx                ; R13 = env

    mov rcx, rbx
    and rcx, TAG_MASK

    cmp rcx, TAG_PRIM
    je .apply_primitive

    cmp rcx, TAG_CONS
    je .apply_lambda

    mov rax, VAL_NIL
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

.apply_primitive:
    mov rax, rbx
    and rax, ~TAG_MASK

    mov rdi, r12
    call rax
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

.apply_lambda:
    mov rdi, rbx
    call _lisp_cdr              ; RAX = (params body)
    mov rbx, rax

    mov rdi, rbx
    call _lisp_car
    mov rdi, rax                ; RDI = params list

    mov rsi, r12                ; RSI = evaled_args list
    mov rdx, r13                ; RDX = env
    call _pairlis
    mov r12, rax                ; R12 = extended env

    mov rdi, rbx
    call _lisp_cdr
    mov rdi, rax
    call _lisp_car              ; RAX = body_expr

    mov rdi, rax
    mov rsi, r12
    call _eval

    pop r13
    pop r12
    pop rbx
    pop rbp
    ret
