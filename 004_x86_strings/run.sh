#!/bin/sh

nasm -f macho64 strings.asm -o strings.o

if [ $? -ne 0 ]; then
    echo "[build] nasm failed"
    exit 1
fi

ld -o strings strings.o -lSystem -syslibroot $(xcrun -sdk macosx --show-sdk-path) -e _main -arch x86_64

if [ $? -ne 0 ]; then
    echo "[link] ld failed"
    exit 1
fi

./strings
