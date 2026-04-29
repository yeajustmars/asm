default rel

global _main

%define SYS_WRITE 0x2000004         ; Syscall: write (macOS)
%define SYS_EXIT  0x2000001         ; Syscall: exit (macOS)
%define STDOUT    1                 ; stdout

section .bss
  memory_box resb 8                 ; Reserve exactly 8 empty bytes (1 QWORD) in the "warehouse"

section .text

_main:
    ; -------------------------------------------------------------------------
    ; NOTES: x86 Registers
    ; -----------------------------------------
    ; The letters in the classic registers actually mean something historically (in x86),
    ; even though they are mostly general-purpose now.
    ;
    ;     'A' (rax): Accumulator (Math and returns)
    ;     'B' (rbx): Base (Originally used for base memory addressing)
    ;     'C' (rcx): Counter (Used implicitly by loop instructions)
    ;     'D' (rdx): Data (Used alongside A for large math operations like multiplication/division)
    ;
    ; -----------------------------------------
    ; The "Big 6" Argument Registers
    ;     If you want to pass data to a function or a system call, you must fill these registers
    ;     in this exact order, from left to right (or top to bottom in the following table):
    ;
    ;     ARGUMENT    REGISTER    HISTORICAL MEANING
    ;     --------    --------    ------------------
    ;     1st         rdi         Distination Index
    ;     2nd         rsi         Source Index
    ;     3rd         rdx         Data Register
    ;     4th         rcx/r10 *   Counter Register
    ;     5th         r8          General Purpose 8
    ;     6th         r9          General Purpose 9
    ;
    ; -----------------------------------------
    ; The 4th Argument Gotcha: Notice the 4th argument has two registers.
    ;     If you are making a System Call (talking to the kernel), you must use r10.
    ;     If you are calling a Normal Function (like a C function from a library), you must use rcx.
    ;     The CPU actually destroys rcx during the syscall instruction, which is why the kernel
    ;     forces you to use r10 instead.
    ;
    ; If a function requires more than 6 arguments, you run out of designated registers.
    ;     At that point, you are forced to push arguments 7, 8, 9, etc.,
    ;     onto the Stack before making the call.
    ; -------------------------------------------------------------------------


    ; -------------------------------------------------------------------------
    ; EXPERIMENT 1: The Russian Nesting Dolls
    ; -----------------------------------------
    ; Keep `rax` free for System Calls.
    ;     The `rax` register (the Accumulator) is the VIP of x86_64. Whenever you want to
    ;     ask the operating system to do something — like print to the screen or exit the
    ;     program — you must put the syscall ID number into `rax`. If we used `rax` to hold
    ;     our 'A's, we would have to juggle that data somewhere else the moment we wanted
    ;     to print it. rbx (the Base register) is a general-purpose "scratchpad" that the
    ;     OS ignores during syscalls.
    ; -------------------------------------------------------------------------

    ; 1. Load full 64-bits (8 bytes) into `rbx`
    ;     `0x41` is the hex ASCII code for 'A'
    ;     `rbx` = "AAAAAAAA" (8 'A' chars)
    ;     0x4141414141414141 = 0x[41][41][41][41][41][41][41][41] (or 8 'A' chars)
    ;                             --  --  --  --  --  --  --  --
    ;                             1   2   3   4   5   6   7   8
    ;     8 x 8 = 64
    mov rbx, 0x4141414141414141     ; rbx = 'AAAAAAAA'

    ; 2. Overwrite the lowest 16 bits (2 bytes) using the `bx` alias
    ;     `0x42` is 'B' in ASCII
    ;     The top 6 bytes or `rbx` remain completely untouched
    ;     `0x4242` = ox[42][42] (or 2 'B' chars)
    ;                   --  --
    ;                   1   2
    ;     8 x 2 = 16
    mov bx, 0x4242                  ; rbx = "AAAAAABB"

    ; 3. Overwrite the absolute lowest 8 bites (1 byte) using the `bl` alias
    ;     `0x43` is 'C' in ASCII.
    ;     8 x 1 = 8
    mov bl, 0x43                    ; rbx = "AAAAAABC"

    ; 4. Now we move the register's contents into memory
    ;     In NASM (Intel syntax), the square brackets [] act as the dereference operator.
    ;     They are the exact assembly equivalent of using a pointer in C (*ptr).
    ;     Think of a label like memory_box as a physical street address, and the brackets []
    ;     as walking through the front door to see what is inside the house.
    ;
    ;     Here is the difference in practice:
    ;
    ;     SYNTAX                   MEANING  C EQUIVALENT          CPU ACTION
    ;     -----------------------  -------  --------------------  --------------------------
    ;     `mov rax, memory_box`    Address  `ptr = &memory_box;`  Loads a memory address
    ;                                                             (e.g., 0x100004000)
    ;                                                             into rax.
    ;
    ;     `mov rax, [memory_box]`  Value    `val = *memory_box;`  Goes to 0x100004000, grabs
    ;                                                             the 8 bytes inside it, and
    ;                                                             puts them in rax.

    ; Save and print
    mov [memory_box], rbx           ; Save to memory
    mov byte [memory_box + 7], 10   ; Replace the 8th byte with a newline
    call print_box                  ; Jump to print_box, then return here

    ; -------------------------------------------------------------------------
    ; EXPERIMENT 2: The Zero-Extension Gotcha
    ; -------------------------------------------------------------------------

    ; 1. Let's try the same thing with the A register (`rax`)
    ;     0x4444444444444444 = 0x[44][44][44][44][44][44][44][44] (or 8 'D' chars)
    ;                             --  --  --  --  --  --  --  --
    ;                             1   2   3   4   5   6   7   8
    ;     8 x 8 = 64
    mov rax, 0x4444444444444444     ; rax = 'DDDDDDDD'

    ; 2. We want to overwrite the lower 32 bits (4 bytes) with 'E' chars
    ;     0x45454545 = 0x[45][45][45][45] (or 4 'E' chars)
    ;                     --  --  --  --
    ;                     1   2   3   4
    ;     8 x 4 = 32
    mov eax, 0x45454545

    ; Save and print
    mov [memory_box], rax           ; Save to memory (overwriting the old data)
    mov byte [memory_box + 7], 10   ; Replace the 8th byte with a newline
    call print_box                  ; Jump to print_box, then return here

    ; Gracefully exit the program
    mov rax, SYS_EXIT
    xor rdi, rdi                    ; Exit code 0
    syscall

print_box:
    ; -------------------------------------------------------------------------
    ; Print the result of an Experiment
    ; -------------------------------------------------------------------------
    ; We use rdi purely because it's the law.
    ;
    ; In the 64-bit world of macOS and Linux, there is a strict rulebook called the
    ; System V AMD64 ABI (Application Binary Interface). This rulebook dictates exactly
    ; how programs are allowed to talk to the operating system and to other functions.
    ;
    ; The most important rule in that book is the Calling Convention: you cannot just
    ; put your arguments wherever you want. You must place them into a very specific
    ; sequence of registers.
    ;
    ; rdi is the designated register for Argument 1.
    ;
    ; How it applies to printing
    ; When you ask the kernel to print something using SYS_WRITE, the kernel expects
    ; exactly three pieces of information (arguments) to execute the command:
    ;     Where am I writing this? (The File Descriptor)
    ;     What am I writing? (The memory address of the string)
    ;     How much am I writing? (The number of bytes)
    ;
    ; Because "Where am I writing this?" is the very first argument, it legally must go into rdi.
    ; By moving 1 (the code for STDOUT) into rdi, we are telling the kernel to direct the text
    ; to the terminal screen instead of a file or a network socket.

    ; 1 Let's replace the final 'A' with a newline (ASCII 10) so it prints nicely.
    ; Because of Little Endianness, the 8th byte is at memory_box + 7.
    mov byte [memory_box + 7], 10

    ; 2. Set argument 1
    ;     STDOUT is just a macro for 1. In UNIX-based systems (like macOS and Linux), 1 is
    ;     the "File Descriptor" for standard output (your terminal window). We are telling
    ;     the kernel, "I want to write to the console."
    mov rdi, STDOUT

    ; 3. Set argument 2
    ;     The kernel needs to know where the data is. `rsi` requires a pointer
    ;     (a memory address). We use lea (Load Effective Address) to calculate the exact
    ;     location of memory_box in RAM and put that address into rsi.
    lea rsi, [memory_box]

    ; 4. Set argument 3
    ;     The kernel needs to know exactly how much data to read from that address so it
    ;     doesn't accidentally print garbage data from neighboring memory. We tell it to
    ;     print exactly 8 bytes.
    mov rdx, 8                    ; We are printing 8 bytes

    ; 5. Set the Syscall number
    ;     Remember, we keep `rax` free for System Calls.
    ;     `rax` is the VIP register used to tell the kernel which action you want.
    ;     SYS_WRITE is a macro for 0x2000004 (the specific ID for the macOS write command).
    mov rax, SYS_WRITE

    ; 6. Make the physical system call
    ;     Hand control to the OS.
    ;     This is the trigger. The CPU instantly suspends your program, switches into
    ;     "Kernel Mode" (Ring 0), looks at rax to see what you want, reads the arguments
    ;     in rdi, rsi, and rdx, prints the 8 bytes to the screen, and then returns control
    ;     back to your program on the very next line of code.
    syscall

    ; 7. Return to caller location
    ret
