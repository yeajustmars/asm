global _main         ; Expose main entry point

section .bss
  buffer resb 20              ; 20 bytes is enough for largest 64-bit number

section .text

; --------------------------------------------------------------------------------
; Function: _add_two_numbers
; Purpose: Sums two numbers
; Returns: RAX (sum)
; --------------------------------------------------------------------------------
_add_two_numbers:
  mov rax, rdi                ; Move arg1 into RAX
  add rax, rsi                ; Add arg2 to RAX
  ret

; --------------------------------------------------------------------------------
; Function: _print_number
; Purpose: Converts a 64-bit integer into an ASCII string and prints it.
; Input: RDI (The integer to print)
; --------------------------------------------------------------------------------
_print_number:
  mov rax, rdi                ; RAX holds the number we are dividing
  mov rcx, 10                 ; RCX is our divisor (base 10)

  lea r8, [rel buffer + 19]   ; We build the string backwards in memory.
                              ; Point R8 to the very end of our 20-byte buffer

  mov byte [r8], 10           ; Put a newline character at the very end
  dec r8                      ; Move pointer back one slot for the first digit

.extract_digit:
  xor rdx, rdx                ; Clear RDX. The 'div' instruction divides RDX:RAX by RCX.
  div rcx                     ; RAX = RAX / 10. RDX = Remainder (the digit)

  add dl, '0'                 ; Convert the number (0-9) to its ASCII character ('0'-'9')
                              ; '0' is 48 in ASCII. So 5 + 48 = 53 (ASCII '5')

  mov [r8], dl                ; Store the character into our buffer
  dec r8                      ; Move the buffer pointer back one slot

  test rax, rax               ; Is our quotient (RAX) 0 yet?
  jnz .extract_digit          ; If not, jump back and extract the next digit

  ; At this point, R8 points to the empty slot just before our first digit
  inc r8                      ; Move R8 forward to point to the actual start of our string

  ; Calculate the string length: End-of-buffer minus Start-of-string
  lea r9, [rel buffer + 20]
  sub r9, r8                  ; R9 now holds the exact length of our string (including newline)

  ; Print the string  via macOS sys_write
  mov rax, 0x2000004          ; sys_write
  mov rdi, 1                  ; File descriptor 1 (stdout)
  mov rsi, r8                 ; Pointer to the start of our string
  mov rdx, r9                 ; Length of our string
  syscall

  ret

; --------------------------------------------------------------------------------
; Function: _add_ints (Variadic)
; Purpose: Sums a variable number of integers.
; Inputs: Arg 1 (RDI) = Count. Args 2-6 = RSI, RDX, RCX, R8, R9. Args 7+ = Stack.
; Returns: RAX (The total sum)
; --------------------------------------------------------------------------------
_add_ints:
  push rbp                    ; Save the caller's base pointer to the stack (Prologue)
  mov rbp, rsp                ; Set our own base pointer to the current top of the stack (Prologue)
  xor rax, rax                ; Clear RAX to 0. This will be our running total.

  test rdi, rdi               ; Check if the count of numbers (RDI) is 0
  jz .done                    ; If count is 0, jump straight to the end

  ; --- Phase 1: Read from Registers ---
  add rax, rsi                ; Add the 1st number (Arg 2) to our total
  dec rdi                     ; Decrease the remaining count by 1
  jz .done                    ; If count hit 0, we are done

  add rax, rdx                ; Add the 2nd number (Arg 3) to our total
  dec rdi                     ; Decrease the remaining count by 1
  jz .done                    ; If count hit 0, we are done

  add rax, rcx                ; Add the 3rd number (Arg 4) to our total
  dec rdi                     ; Decrease the remaining count by 1
  jz .done                    ; If count hit 0, we are done

  add rax, r8                 ; Add the 4th number (Arg 5) to our total
  dec rdi                     ; Decrease the remaining count by 1
  jz .done                    ; If count hit 0, we are done

  add rax, r9                 ; Add the 5th number (Arg 6) to our total
  dec rdi                     ; Decrease the remaining count by 1
  jz .done                    ; If count hit 0, we are done

  ; --- Phase 2: Read from the Stack ---
  mov r10, 16                 ; We ran out of registers. Set R10 to 16 bytes
                              ; (the offset to bypass RBP and the return address)

.stack_loop:
  add rax, qword [rbp + r10]  ; Grab 8 bytes (a 'quad word') from the stack at
                              ; (Base Pointer + Offset) and add to total

  add r10, 8                  ; Increase our offset by 8 bytes to point to
                              ; the next number down the Stack

  dec rdi                     ; Decrease the remaining count by 1
  jnz .stack_loop             ; If count is not 0, loop back to grab the next number from the stack

.done:
  pop rbp                     ; Restore the caller's base pointer from the Stack (Epilogue)
  ret                         ; Jump back to the caller, leaving our final sum in RAX

; --------------------------------------------------------------------------------
; Main Entry Point
; --------------------------------------------------------------------------------
_main:
  ; -----------------------------------------------------------------------
  ; 1. Call _add_two_numbers with 25, 17
  ; -----------------------------------------------------------------------
  mov rdi, 25                 ; Arg1 = 25
  mov rsi, 17                 ; Arg2 = 17
  call _add_two_numbers       ; Result 42 is placed in RAX

  ; -----------------------------------------------------------------------
  ; 2. Print number _add_two_numbers put in RAX
  ; -----------------------------------------------------------------------
  mov rdi, rax                ; Move the math result (42) into RDI as the argument for _print_number
  call _print_number

  ; -----------------------------------------------------------------------
  ; 3. Call _add_ints using just Registers (no Stack)
  ; _add_ints 10 10 = 20
  ; -----------------------------------------------------------------------
  mov rdi, 2                  ; We're passing 2 numbers (similar to _add_two_numbers function)
  mov rsi, 10                 ; 1st number
  mov rdx, 10                 ; 2nd number

  xor al, al                  ; Clear AL (lowest 8 bits of RAX) to 0
                              ; Required by ABI to indicate 0 floating-point arguments

  call _add_ints              ; Execute our function. The CPU pushes the return address and jumps
                              ; RAX will contain 20

  mov rdi, rax                ; Move our result (20) from RAX to RDI to act as the argument to _print_number
  call _print_number


  ; -----------------------------------------------------------------------
  ; 4. Call _add_ints using Registers and Stack
  ; _add_ints 1 2 3 4 5 6 7 8 9 = 45
  ; ABI Rule: Arguments beyond the 6th must be pushed in reverse.
  ;           (which means the 5th number to sum, since count is arg 1)
  ; -----------------------------------------------------------------------
  push 9                      ; Push the last number, first
  push 8                      ; Push the second-to-last number, next
  push 7                      ; Push the third-to-last number
  push 6                      ; Push the fourth-to-last number. After this, we can use registers (n1 - n5)
  mov rdi, 9                  ; We are passing 9 numbers in total
  mov rsi, 1                  ; Now we go in order, registering the first 5 number ascending
  mov rdx, 2                  ; 2nd number
  mov rcx, 3                  ; 3rd number
  mov r8, 4                   ; 4th number
  mov r9, 5                   ; 5th number
  xor al, al                  ; Clear AL to indicate 0 floating point arguments
  call _add_ints              ; Add ints. RAX will contain 45
  add rsp, 32                 ; CRITICAL: We pushed 4 8-byte numbers to the stack.
                              ; We must add 32 to the Stack Pointer to remove them.
  mov rdi, rax                ; Move our result (45) from RAX to RDI
  call _print_number          ; Execute the print function



  ; N. Exit the program cleanly
  mov rax, 0x2000001          ; macOS sys_exit
  mov rdi, 0                  ; Exit code 0 (Success)
  syscall

