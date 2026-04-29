#!/bin/sh

mkdir -p target

nasm -f macho64 input.asm -o target/input.o

if [ $? -ne 0 ]; then
    echo "[build] nasm failed"
    exit 1
fi

ld -o target/input target/input.o -lSystem -syslibroot $(xcrun -sdk macosx --show-sdk-path) -e _main -arch x86_64

if [ $? -ne 0 ]; then
    echo "[link] ld failed"
    exit 1
fi

echo -e "Usage: ./target/input string1 string2 string3\n"
