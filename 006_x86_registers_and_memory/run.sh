#!/bin/sh

mkdir -p target

nasm -f macho64 registers_and_memory.asm -o target/registers_and_memory.o

if [ $? -ne 0 ]; then
    echo "[build] nasm failed"
    exit 1
fi

ld -o target/registers_and_memory target/registers_and_memory.o \
   -lSystem \
   -syslibroot $(xcrun -sdk macosx --show-sdk-path) \
   -e _main \
   -arch x86_64

if [ $? -ne 0 ]; then
    echo "[link] ld failed"
    exit 1
fi

./target/registers_and_memory
