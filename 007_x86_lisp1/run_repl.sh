#!/bin/bash
set -e

mkdir -p target

echo "[1/3] Assembling Lisp engine and REPL..."
nasm -f macho64 lisp.asm -o target/lisp.o
nasm -f macho64 repl.asm -o target/repl.o

echo "[2/3] Linking LISP-1 executable..."
ld -o target/lisp_repl \
   target/lisp.o \
   target/repl.o \
   -lSystem \
   -syslibroot $(xcrun -sdk macosx --show-sdk-path) \
   -e _main \
   -arch x86_64

echo "[3/3] Launching REPL..."
echo ""
./target/lisp_repl
