#!/bin/sh

# Assemble using NASM for 64-bit macOS
nasm -f macho64 functions.asm -o functions.o
if [ $? -ne 0 ]; then
    echo "[build] nasm failed"
    exit 1
fi

# Link using x86_64 architecture and libSystem
clang -arch x86_64 functions.o -o run_functions
if [ $? -ne 0 ]; then
    echo "[link] clang failed"
    exit 1
fi

./run_functions
