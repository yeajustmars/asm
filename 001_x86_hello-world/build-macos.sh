#!/bin/sh

mkdir -p target

nasm -f macho64 -o target/hello-macos.o -l target/hello-macos.lst hello-macos.asm
ld -static -o target/hello-macos target/hello-macos.o

echo "Run it via ./target/hello-macos"
