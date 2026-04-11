; Play1: playing around with ASM

;;;; --------------------------------------------------------------------------------------- Example 1
;;;; Print "Hello, World!"

;; global _main
;; default rel                 ; This fixes your absolute address error
;;
;; section .data
;;     msg db 'Hello, World!'
;;
;; section .text
;; _main:
;;     ; syscall: sys_write
;;     mov rax, 0x2000004      ; macOS x86_64 syscalls add 0x2000000 to the class! 4 = write
;;     mov rdi, 1              ; file descriptor: stdout
;;     lea rsi, [msg]          ; Load Effective Address (relative pointer to message)
;;     mov rdx, 13             ; message length
;;     syscall                 ; macOS 64-bit uses 'syscall', not 'int 0x80'
;;
;;     ; syscall: sys_exit
;;     mov rax, 0x2000001      ; 1 = exit
;;     xor rdi, rdi            ; exit code: 0
;;     syscall

;;;; --------------------------------------------------------------------------------------- Example 2
;;;; Add 2 numbers and return the result as the exit code

;; global _main
;; default rel
;;
;; section .text
;; _main:
;;   ; 1. Load our 2 numbers into registers
;;   mov rax, 15           ; Put the number 15 into register rax
;;   mov rbx, 27           ; Put the number 27 into register rbx
;;
;;   ; 2. Add them together
;;   add rax, rbx          ; Add rbx to rax. The result (42) is stored in rax
;;
;;   ; 3. Setup the the exit syscall
;;   ; In macOS x86_64, the 'rdi' register holds the exit status code
;;   mov rdi, rax          ; So, we move our sum from 'rax' into 'rdi'
;;
;;   ; 4. Call the kernel to exit
;;   mov rax, 0x2000001    ; macOS x86_64 syscall for 'exit'
;;   syscall


;;;; --------------------------------------------------------------------------------------- Example 3
;;;; Add 2 numbers and print them as ASCII output, returning a successful status code of zero

;; global _main
;; default rel
;;
;; ; We need a place in memory to store our our converted ASCII string before printing it
;; ; The .bss section is used for reserving uninitialized memory
;;
;; section .bss
;;   buffer resb 20    ; Reserve a 20-byte buffer for our output string
;;
;; section .text
;; _main:
;;   ; 1. Do the math
;;
;;   mov rax, 15
;;   mov rbx, 27
;;   add rax, rbx ; rax now holds 42
;;
;;   ; 2. Convert integer to string
;;   ; We will fill our buffer from the back to the front
;;
;;   lea  rsi, [rel buffer]  ; Load the base address of our buffer
;;   add rsi, 19             ; Move the pointer to the very end of the 20-byte buffer
;;   mov byte [rsi], 10      ; Put a newline char at the end of the buffer
;;
;;   mov rcx, 1              ; This will be our string length counter (starts at 1 for the newline char)
;;   mov r8, 10              ; Divide by 10 to isolate digits
;;
;; .convert_loop:
;;   xor rdx, rdx      ; Clear rdx. The 'div' instruction divides rdx:rdx by r8
;;                     ; If we don't clear rdx, it will create a math fault
;;
;;   div r8            ; rax = rax / 10 (quotient), rdx = rdx % 10 (remainder)
;;
;;   add dl, '0'       ; Convert the ramainder in dl to is ASCII character
;;
;;   dec rsi           ; Move our buffer pointer backwards by 1 byte
;;   mov [rsi], dl     ; Store the ASCII char in the buffer
;;   inc rcx           ; Increment our string length counter
;;
;;   test rax, rax     ; Check if quotient (rax) is zero
;;   jnz .convert_loop ; If it's not 0 (Jump if not zero), keep looping
;;
;;   ; 3. Print the string
;;   ; Right now, rsi is pointing to the exact start of our newly formed string in the buffer
;;   ; and rcx  holds the exact length of the string
;;
;;   mov rax, 0x2000004  ; macOS x86_64 syscall: sys_write
;;   mov rdi, 1          ; file descriptor: 1 (stdout)
;;                       ; rsi already contains the pointer to the start of our string
;;   mov rdx, rcx        ; Length of the string
;;   syscall
;;
;;   ; 4. Exit cleanly
;;   mov rax, 0x2000001  ; macOS x86_64 syscall: sys_exit
;;   xor rdi, rdi        ; exit status 0 (xor a register with itself zeroes it out efficiently)
;;   syscall

;;;; --------------------------------------------------------------------------------------- Example 4
;;;; For the sake of learning, let's refactor Example 3, using subroutines just to demo
;;;; code organization. We will add overhead here, and any small subroutine _should_ be
;;;; inlined for the sake of performance and not jumping and pushing/popping to the stack
;;;; but we'll do it anyway for the sake of implementing an almost functional approach to ASM.

;; global _main
;; default rel
;;
;; section .bss
;;   buffer resb 20
;;
;; section .text
;; _main:
;;   ; 1. Setup arguments and call add_numbers
;;   mov rdi, 15         ; Argument 1
;;   mov rsi, 27         ; Argument 2
;;   call add_numbers    ; ! This is wasteful and would be much faster inlined!
;;
;;   ; 2. Setup arguments and call print_integer
;;   mov rdi, rax        ; The print_integer subroutine expects the number in rdi
;;   call print_integer  ; Jump to subroutine
;;
;;   ; 3. Setup arguments and exit
;;   mov rdi, 0          ; Exit code 0
;;   call exit_program   ; ! This is very wasteful given its 2 opcodes. Don't do in normal code. !
;;
;; add_numbers:
;;   mov rax, rdi  ; Move the first number into our return register
;;   add rax, rsi  ; Add the second number to rax
;;   ret           ; Return to where we were called from
;;
;; print_integer:
;;   mov rax, rdi ; Move out target number into rax for division
;;   lea rsi, [rel buffer]
;;   add rsi, 19
;;   mov byte [rsi], 10 ; Newline char
;;   mov rcx, 1
;;   mov r8, 10
;;
;; .convert_loop:
;;   xor rdx, rdx
;;   div r8
;;   add dl, '0'
;;   dec rsi
;;   mov [rsi], dl
;;   inc rcx
;;   test rax, rax
;;   jnz .convert_loop
;;
;;   mov rax, 0x2000004  ; sys_write
;;   mov rdi, 1          ; stdout
;;   mov rdx, rcx        ; string length
;;   syscall             ; rsi is already pointing to start of string from loop
;;   ret                 ; return to _main
;;
;; exit_program:
;;   mov rax, 0x2000001 ; sys_exit
;;   syscall ; rdi already holds our exit code from when we called this syscall
;;   ; No `ret` needed, the OS kills the program

;;;; --------------------------------------------------------------------------------------- Example 5
;;;; Let's optimize Example 4 for performance, while still keeping some code organization

global _main
default rel

section .bss
  buffer resb 20

section .text
_main:
  ; 1. Add numbers
  mov rdi, 15
  add rdi, 27

  ; 2. Print integer
  call print_integer  ; Jump to subroutine

  ; 3. Exit 0
  mov rdi, 0          ; Exit code 0
  mov rax, 0x2000001 ; sys_exit
  syscall ; rdi already holds our exit code from when we called this syscall

print_integer:
  mov rax, rdi ; Move out target number into rax for division
  lea rsi, [rel buffer]
  add rsi, 19
  mov byte [rsi], 10 ; Newline char
  mov rcx, 1
  mov r8, 10

.convert_loop:
  xor rdx, rdx
  div r8
  add dl, '0'
  dec rsi
  mov [rsi], dl
  inc rcx
  test rax, rax
  jnz .convert_loop

  mov rax, 0x2000004  ; sys_write
  mov rdi, 1          ; stdout
  mov rdx, rcx        ; string length
  syscall             ; rsi is already pointing to start of string from loop
  ret                 ; return to _main
