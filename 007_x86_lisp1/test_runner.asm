; ==============================================================================
; Pure x86_64 Assembly Unit Test Runner
; Executable test suite verifying Phases 1, 2, 3, 4, & 5 Functionality
; ==============================================================================

default rel

%include "constants.inc"

; Heap & Conversion Externs
extern _lisp_init
extern _lisp_alloc
extern _lisp_cons
extern _lisp_car
extern _lisp_cdr
extern _int_to_fixnum
extern _fixnum_to_int

; Symbol Externs
extern _intern_symbol
extern _symbol_name
extern _symbol_val
extern _set_symbol_val

; Reader, Printer, & IO Externs
extern _read_sexpr
extern _sprint_sexpr
extern _print_sexpr
extern _print_string
extern _print_char

; Primitives & Environment Externs
extern _prim_car
extern _prim_cdr
extern _prim_cons
extern _prim_eq
extern _prim_atom
extern _prim_add
extern _prim_sub
extern _prim_mul
extern _assoc

; Universal EVAL / APPLY Externs
extern _pairlis
extern _evlis
extern _eval
extern _apply

section .bss
    out_buf: resb 1024          ; Buffer for printer testing

section .data
    msg_start:  db "=== Running LISP-1 Assembly Test Suite ===", 10, 0
    msg_pass:   db "  [PASS] ", 0
    msg_fail:   db "  [FAIL] ", 0
    msg_done:   db 10, "All tests completed successfully!", 10, 0

    ; Strings for Symbol Interning Test
    str_car:    db "CAR", 0
    str_cdr:    db "CDR", 0

    ; Strings for Reader Unit Test
    str_num_in:   db "  -12345 ", 0
    str_sym_in:   db "  MY-SYMBOL ", 0
    str_nil_in:   db "  NIL ", 0
    str_list_in:  db "(100 200)", 0
    str_dot_in:   db "(1 . 2)", 0
    str_quote_in: db "'BAR", 0

    ; Round-Trip S-Expr test input and expected output strings
    str_complex_in:  db "(A (10 . -20) NIL 'FOO)", 0
    str_complex_exp: db "(A (10 . -20) NIL (QUOTE FOO))", 0

    ; Strings for Phase 4 Unit Test
    str_alist_in:    db "((X . 100) (Y . 200) (Z . 300))", 0
    str_key_y:       db "Y", 0

    ; Strings for Phase 5 Universal EVAL Unit Test
    str_eval_num:    db "42", 0
    str_eval_quote:  db "'(10 20 30)", 0
    str_eval_add:    db "(+ 15 27)", 0
    str_eval_cond:   db "(COND ((EQ 1 2) 100) ((EQ 2 2) 200) (T 300))", 0
    str_def_sq:      db "(DEFINE SQUARE (LAMBDA (N) (* N N)))", 0
    str_call_sq:     db "(SQUARE 7)", 0
    str_def_fact:    db "(DEFINE FACT (LAMBDA (N) (COND ((EQ N 0) 1) (T (* N (FACT (- N 1)))))))", 0
    str_call_fact:   db "(FACT 5)", 0

    ; Test Descriptions
    t1_name:    db "Test 1: Heap Allocation & Initialization", 0
    t2_name:    db "Test 2: Fixnum Encoding and Decoding", 0
    t3_name:    db "Test 3: CONS Cell Creation and CAR/CDR Access", 0
    t4_name:    db "Test 4: Symbol Interning, Uniqueness, and Value Cells", 0
    t5_name:    db "Test 5: S-Expression Reader (Numbers, Symbols, Lists, Dotted, Quotes)", 0
    t6_name:    db "Test 6: S-Expression Printer & Round-Trip Formatting", 0
    t7_name:    db "Test 7: McCarthy Primitives (EQ, ATOM, Math) & Environment Lookup (ASSOC)", 0
    t8_name:    db "Test 8: Universal EVAL Evaluator (Forms, QUOTE, COND, DEFINE, & Recursive Functions)", 0

section .text

global _main

_main:
    push rbp
    mov rbp, rsp

    lea rdi, [rel msg_start]
    call _print_string

    ; Initialize Engine Heap & Special Symbols
    call _lisp_init
    cmp rax, 0
    je .init_ok

    mov rdi, 1
    call _exit_program

.init_ok:
    call test1_heap_init
    call test2_fixnums
    call test3_cons_car_cdr
    call test4_symbols
    call test5_reader
    call test6_printer
    call test7_primitives_assoc
    call test8_eval_engine

    lea rdi, [rel msg_done]
    call _print_string

    mov rdi, 0
    call _exit_program

; ------------------------------------------------------------------------------
; Unit Tests
; ------------------------------------------------------------------------------

test1_heap_init:
    push rbp
    mov rbp, rsp

    mov rdi, 32
    call _lisp_alloc

    test rax, rax
    jnz .t1_pass

    lea rdi, [rel t1_name]
    call _assert_fail
    pop rbp
    ret

.t1_pass:
    lea rdi, [rel t1_name]
    call _assert_pass
    pop rbp
    ret

test2_fixnums:
    push rbp
    mov rbp, rsp

    mov rdi, 42
    call _int_to_fixnum
    mov rbx, rax

    mov rcx, rbx
    and rcx, TAG_MASK
    cmp rcx, TAG_FIXNUM
    jne .t2_fail

    mov rdi, rbx
    call _fixnum_to_int
    cmp rax, 42
    jne .t2_fail

    lea rdi, [rel t2_name]
    call _assert_pass
    pop rbp
    ret

.t2_fail:
    lea rdi, [rel t2_name]
    call _assert_fail
    pop rbp
    ret

test3_cons_car_cdr:
    push rbp
    mov rbp, rsp

    mov rdi, 10
    call _int_to_fixnum
    mov rbx, rax

    mov rdi, 20
    call _int_to_fixnum
    mov r12, rax

    mov rdi, rbx
    mov rsi, r12
    call _lisp_cons
    mov r13, rax

    mov rdi, r13
    call _lisp_car
    cmp rax, rbx
    jne .t3_fail

    mov rdi, r13
    call _lisp_cdr
    cmp rax, r12
    jne .t3_fail

    lea rdi, [rel t3_name]
    call _assert_pass
    pop rbp
    ret

.t3_fail:
    lea rdi, [rel t3_name]
    call _assert_fail
    pop rbp
    ret

test4_symbols:
    push rbp
    mov rbp, rsp

    lea rdi, [rel str_car]
    call _intern_symbol
    mov rbx, rax

    mov rcx, rbx
    and rcx, TAG_MASK
    cmp rcx, TAG_SYMBOL
    jne .t4_fail

    lea rdi, [rel str_car]
    call _intern_symbol
    cmp rax, rbx
    jne .t4_fail

    lea rdi, [rel str_cdr]
    call _intern_symbol
    mov r12, rax
    cmp r12, rbx
    je .t4_fail

    mov rdi, 999
    call _int_to_fixnum
    mov r13, rax

    mov rdi, rbx
    mov rsi, r13
    call _set_symbol_val

    mov rdi, rbx
    call _symbol_val
    cmp rax, r13
    jne .t4_fail

    lea rdi, [rel t4_name]
    call _assert_pass
    pop rbp
    ret

.t4_fail:
    lea rdi, [rel t4_name]
    call _assert_fail
    pop rbp
    ret

test5_reader:
    push rbp
    mov rbp, rsp

    lea rdi, [rel str_num_in]
    call _read_sexpr
    mov rdi, rax
    call _fixnum_to_int
    cmp rax, -12345
    jne .t5_fail

    lea rdi, [rel str_sym_in]
    call _read_sexpr
    mov rbx, rax
    mov rcx, rbx
    and rcx, TAG_MASK
    cmp rcx, TAG_SYMBOL
    jne .t5_fail

    lea rdi, [rel str_nil_in]
    call _read_sexpr
    cmp rax, VAL_NIL
    jne .t5_fail

    lea rdi, [rel str_list_in]
    call _read_sexpr
    mov rbx, rax

    mov rdi, rbx
    call _lisp_car
    mov rdi, rax
    call _fixnum_to_int
    cmp rax, 100
    jne .t5_fail

    mov rdi, rbx
    call _lisp_cdr
    mov r12, rax
    mov rdi, r12
    call _lisp_car
    mov rdi, rax
    call _fixnum_to_int
    cmp rax, 200
    jne .t5_fail

    mov rdi, r12
    call _lisp_cdr
    cmp rax, VAL_NIL
    jne .t5_fail

    lea rdi, [rel str_dot_in]
    call _read_sexpr
    mov rbx, rax

    mov rdi, rbx
    call _lisp_car
    mov rdi, rax
    call _fixnum_to_int
    cmp rax, 1
    jne .t5_fail

    mov rdi, rbx
    call _lisp_cdr
    mov rdi, rax
    call _fixnum_to_int
    cmp rax, 2
    jne .t5_fail

    lea rdi, [rel str_quote_in]
    call _read_sexpr
    mov rbx, rax

    mov rdi, rbx
    call _lisp_car
    call _symbol_name
    mov rdi, rax
    lea rsi, [rel str_quote_test_name]
    call _streq_test
    cmp rax, 1
    jne .t5_fail

    mov rdi, rbx
    call _lisp_cdr
    mov rdi, rax
    call _lisp_car
    call _symbol_name
    mov rdi, rax
    lea rsi, [rel str_bar_test_name]
    call _streq_test
    cmp rax, 1
    jne .t5_fail

    lea rdi, [rel t5_name]
    call _assert_pass
    pop rbp
    ret

.t5_fail:
    lea rdi, [rel t5_name]
    call _assert_fail
    pop rbp
    ret

test6_printer:
    push rbp
    mov rbp, rsp

    lea rdi, [rel str_complex_in]
    call _read_sexpr
    mov rbx, rax

    mov rdi, rbx
    lea rsi, [rel out_buf]
    call _sprint_sexpr

    lea rdi, [rel out_buf]
    lea rsi, [rel str_complex_exp]
    call _streq_test
    cmp rax, 1
    jne .t6_fail

    lea rdi, [rel t6_name]
    call _assert_pass
    pop rbp
    ret

.t6_fail:
    lea rdi, [rel t6_name]
    call _assert_fail
    pop rbp
    ret

test7_primitives_assoc:
    push rbp
    mov rbp, rsp

    mov rdi, 50
    call _int_to_fixnum
    mov rbx, rax

    mov rdi, rbx
    mov rsi, VAL_NIL
    call _lisp_cons
    mov rsi, rax
    mov rdi, rbx
    call _lisp_cons

    call _prim_eq
    cmp rax, VAL_TRUE
    jne .t7_fail

    mov rdi, rbx
    mov rsi, VAL_NIL
    call _lisp_cons
    call _prim_atom
    cmp rax, VAL_TRUE
    jne .t7_fail

    mov rdi, 1
    call _int_to_fixnum
    mov rbx, rax
    mov rdi, 2
    call _int_to_fixnum
    mov rsi, rax
    call _lisp_cons
    mov rdi, rax
    mov rsi, VAL_NIL
    call _lisp_cons
    call _prim_atom
    cmp rax, VAL_NIL
    jne .t7_fail

    mov rdi, 30
    call _int_to_fixnum
    mov rbx, rax
    mov rdi, 12
    call _int_to_fixnum
    mov rsi, rax
    mov rdi, rsi
    mov rsi, VAL_NIL
    call _lisp_cons
    mov rsi, rax
    mov rdi, rbx
    call _lisp_cons

    call _prim_add
    call _fixnum_to_int
    cmp rax, 42
    jne .t7_fail

    lea rdi, [rel str_alist_in]
    call _read_sexpr
    mov r12, rax

    lea rdi, [rel str_key_y]
    call _intern_symbol
    mov rbx, rax

    mov rdi, rbx
    mov rsi, r12
    call _assoc
    mov r13, rax

    mov rdi, r13
    call _lisp_cdr
    call _fixnum_to_int
    cmp rax, 200
    jne .t7_fail

    lea rdi, [rel t7_name]
    call _assert_pass
    pop rbp
    ret

.t7_fail:
    lea rdi, [rel t7_name]
    call _assert_fail
    pop rbp
    ret

test8_eval_engine:
    push rbp
    mov rbp, rsp

    ; 1. Eval Fixnum: (EVAL 42 NIL) -> 42
    lea rdi, [rel str_eval_num]
    call _read_sexpr
    mov rdi, rax
    mov rsi, VAL_NIL
    call _eval
    call _fixnum_to_int
    cmp rax, 42
    jne .t8_fail

    ; 2. Eval QUOTE: (EVAL '(QUOTE (10 20 30)) NIL) -> (10 20 30)
    lea rdi, [rel str_eval_quote]
    call _read_sexpr
    mov rdi, rax
    mov rsi, VAL_NIL
    call _eval
    mov rbx, rax

    mov rdi, rbx
    call _lisp_car
    call _fixnum_to_int
    cmp rax, 10
    jne .t8_fail

    ; 3. Eval Primitive Math: (EVAL '(+ 15 27) NIL) -> 42
    lea rdi, [rel str_eval_add]
    call _read_sexpr
    mov rdi, rax
    mov rsi, VAL_NIL
    call _eval
    call _fixnum_to_int
    cmp rax, 42
    jne .t8_fail

    ; 4. Eval COND: (EVAL '(COND ((EQ 1 2) 100) ((EQ 2 2) 200) (T 300)) NIL) -> 200
    lea rdi, [rel str_eval_cond]
    call _read_sexpr
    mov rdi, rax
    mov rsi, VAL_NIL
    call _eval
    call _fixnum_to_int
    cmp rax, 200
    jne .t8_fail

    ; 5. Define User Function SQUARE: (DEFINE SQUARE (LAMBDA (N) (* N N)))
    lea rdi, [rel str_def_sq]
    call _read_sexpr
    mov rdi, rax
    mov rsi, VAL_NIL
    call _eval

    ; Evaluate (SQUARE 7) -> 49
    lea rdi, [rel str_call_sq]
    call _read_sexpr
    mov rdi, rax
    mov rsi, VAL_NIL
    call _eval
    call _fixnum_to_int
    cmp rax, 49
    jne .t8_fail

    ; 6. Define Recursive Function FACT: (DEFINE FACT (LAMBDA (N) (COND ((EQ N 0) 1) (T (* N (FACT (- N 1)))))))
    lea rdi, [rel str_def_fact]
    call _read_sexpr
    mov rdi, rax
    mov rsi, VAL_NIL
    call _eval

    ; Evaluate (FACT 5) -> 120
    lea rdi, [rel str_call_fact]
    call _read_sexpr
    mov rdi, rax
    mov rsi, VAL_NIL
    call _eval
    call _fixnum_to_int
    cmp rax, 120
    jne .t8_fail

    lea rdi, [rel t8_name]
    call _assert_pass
    pop rbp
    ret

.t8_fail:
    lea rdi, [rel t8_name]
    call _assert_fail
    pop rbp
    ret

section .data
    str_quote_test_name: db "QUOTE", 0
    str_bar_test_name:   db "BAR", 0

section .text

_streq_test:
    push rbp
    mov rbp, rsp
.loop:
    mov al, [rdi]
    mov bl, [rsi]
    cmp al, bl
    jne .no
    test al, al
    jz .yes
    inc rdi
    inc rsi
    jmp .loop
.yes:
    mov rax, 1
    pop rbp
    ret
.no:
    xor rax, rax
    pop rbp
    ret

; ------------------------------------------------------------------------------
; Assertion & Execution Utilities
; ------------------------------------------------------------------------------
_assert_pass:
    push rbp
    mov rbp, rsp
    push rdi

    lea rdi, [rel msg_pass]
    call _print_string

    pop rdi
    call _print_string

    mov rdi, 10
    call _print_char

    pop rbp
    ret

_assert_fail:
    push rbp
    mov rbp, rsp
    push rdi

    lea rdi, [rel msg_fail]
    call _print_string

    pop rdi
    call _print_string

    mov rdi, 10
    call _print_char

    mov rdi, 1
    call _exit_program

_exit_program:
    mov rax, SYS_EXIT
    syscall
