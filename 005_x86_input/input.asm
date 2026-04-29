default rel

%define SYS_WRITE 0x2000004   ; macOS/BSD syscall for write
%define SYS_EXIT  0x2000001   ; macOS/BSD syscall for exit
%define STDOUT    1           ; number for stdout

global _main                  ; declare main entrypoint

section .bss
  out_buffer resb 4096        ; (res)erve (b)tyes - 4k for output buffer

section .text

; -----------------------------------------------------------------------------
; _main: Entry point
; Input from OS: rdi = argc, rsi = argv (pointer to array of string pointers)
; -----------------------------------------------------------------------------
_main:
  ; 1. Check if we have arguments to process. We require 2 (argc, argv).
  cmp rdi, 2                  ; argc < 2? (only argv[0] exists)
  jl .exit                    ; If so, nothing to do, just exit

  ; 2. Set up tracking registers
  mov r12, rdi                ; r12 = remaining arguments to process (argc)
  dec r12                     ; decrement because we skip argv[0] (script name)

  add rsi, 8                  ; advance argv pointer by 8 bytes (64 bits) to skip argv[0]
  mov r13, rsi                ; r13 = pointer to current argv string pointer
  lea r14, [out_buffer]       ; r14 = current write position in out_buffer

.process_arg:
  mov rbx, [r13]              ; rbx = pointer to actual string for this argument
  test rbx, rbx               ; Safety check: is it a NULL pointer?
  jz .finish_concat

.copy_char:
  mov al, [rbx]               ; Read 1 byte from the argument string
  test al, al                 ; Is it the NULL terminator?
  jz .arg_done                ; If yes, we finished copying this word

  mov [r14], al               ; Write byte to output buffer
  inc rbx                     ; Advance read pointer
  inc r14                     ; Advance write pointer
  jmp .copy_char

.arg_done:
  dec r12                     ; We finished one argument, decrement the counter
  jz .finish_concat           ; If counter is 0, we are on the last word. Don't add a space.

  ; Add the space delimiter
  mov byte [r14], ' '         ; Append a space
  inc r14                     ; Advance write pointer

  add r13, 8                  ; Advance argv array pointer to the next string pointer
  jmp .process_arg            ; Process the next argument

.finish_concat:
  ; Append a newline to make the console output clean
  mov byte [r14], 10          ; 10 is the ASCII code for newline (\n)
  inc r14                     ;

  ; 3. Calculate string length and print
  ; Length = (current write position) - (start of buffer)
  lea r15, [out_buffer]
  mov rdx, r14
  sub rdx, r15                ; rdx now contains the exact length of the string

  mov rdi, STDOUT             ; Arg 1: stdout
  lea rsi, [out_buffer]       ; Arg 2: string buffer
  mov rax, SYS_WRITE          ; Syscall: write
  syscall

.exit:
  mov rax, SYS_EXIT           ; Syscall: exit
  xor rdi, rdi                ; Exit code 0
  syscall

