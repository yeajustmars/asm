; ==============================================================================
; LISP-1 Constants & Subroutine Interface Definitions (macOS x86_64)
; ==============================================================================

; --- macOS BSD System Calls ---
%define SYS_EXIT  0x2000001
%define SYS_READ  0x2000003
%define SYS_WRITE 0x2000004
%define SYS_MMAP  0x20000C5

%define STDOUT 1
%define STDERR 2

; --- Memory Protection & Flags for sys_mmap ---
%define PROT_READ   0x01
%define PROT_WRITE  0x02
%define MAP_PRIVATE 0x0002
%define MAP_ANON    0x1000

; --- 3-Bit Tagging Scheme (Bits 0-2) ---
%define TAG_MASK   0x07        ; Bitmask to extract tag (0b111)
%define TAG_CONS   0x00        ; 000b - Pointer to 16-byte aligned CONS cell
%define TAG_SYMBOL 0x01        ; 001b - Pointer to Symbol Structure
%define TAG_FIXNUM 0x02        ; 010b - 61-bit Signed Inline Integer
%define TAG_PRIM   0x03        ; 011b - Pointer to Native Primitive Subroutine
%define TAG_CONST  0x04        ; 100b - Special Constant (NIL, T)

; --- Special Constant Values ---
%define VAL_NIL    0x04        ; Tagged CONST with payload 0 -> (0 << 3) | 4 = 0x04
%define VAL_TRUE   0x0C        ; Tagged CONST with payload 1 -> (1 << 3) | 4 = 0x0C

; --- Heap Arena Size (64 MB) ---
%define HEAP_SIZE  67108864
