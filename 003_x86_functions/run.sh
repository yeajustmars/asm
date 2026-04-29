#!/bin/sh

mkdir -p target

# Assemble using NASM for 64-bit macOS
nasm -f macho64 functions.asm -o target/functions.o
if [ $? -ne 0 ]; then
    echo "[build] nasm failed"
    exit 1
fi

# Link using x86_64 architecture and libSystem
clang -arch x86_64 target/functions.o -o target/run_functions
if [ $? -ne 0 ]; then
    echo "[link] clang failed"
    exit 1
fi

./target/run_functions
