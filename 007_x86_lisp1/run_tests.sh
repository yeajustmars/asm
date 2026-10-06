#!/bin/bash
set -e

mkdir -p target

echo "[1/3] Assembling engine modules..."
nasm -f macho64 lisp.asm -o target/lisp.o
nasm -f macho64 test_runner.asm -o target/test_runner.o

echo "[2/3] Linking test runner executable..."
ld -o target/test_runner \
   target/lisp.o \
   target/test_runner.o \
   -lSystem \
   -syslibroot $(xcrun -sdk macosx --show-sdk-path) \
   -e _main \
   -arch x86_64

echo "[3/3] Executing Assembly Unit Tests..."
echo ""
./target/test_runner
