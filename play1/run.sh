#!/bin/sh

# Assemble using NASM for 64-bit macOS
nasm -f macho64 -o play1.o play1.asm
if [ $? -ne 0 ]; then
    echo "[build] nasm failed"
    exit 1
fi

# Link using x86_64 architecture and libSystem
ld -o play1 play1.o -lSystem -syslibroot $(xcrun -sdk macosx --show-sdk-path) -e _main -arch x86_64
if [ $? -ne 0 ]; then
    echo "[link] ld failed"
    exit 1
fi

./play1
