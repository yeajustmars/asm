#!/bin/sh

mkdir -p target

nasm -f macho64 strings2.asm -o target/strings2.o

if [ $? -ne 0 ]; then
    echo "[build] nasm failed"
    exit 1
fi

ld -o target/strings2 target/strings2.o -lSystem -syslibroot $(xcrun -sdk macosx --show-sdk-path) -e _main -arch x86_64

if [ $? -ne 0 ]; then
    echo "[link] ld failed"
    exit 1
fi

./target/strings2
