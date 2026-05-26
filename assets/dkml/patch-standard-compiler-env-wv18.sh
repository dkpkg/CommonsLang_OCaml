#!/bin/sh
set -eu

file=$1
tmp="$file.tmp"

{
    while IFS= read -r line; do
        if [ "$line" = '    CFLAGS_MSVC="${autodetect_compiler_CFLAGS}"    ' ]; then
            printf '%s\n' '    # VS 2026 / MSVC 19.50 warns on mixed enum comparisons in OCaml 4.14 runtime code.'
            printf '%s\n' '    CFLAGS_MSVC="${autodetect_compiler_CFLAGS:+$autodetect_compiler_CFLAGS }/Wv:18"'
        else
            printf '%s\n' "$line"
        fi
    done < "$file"
} > "$tmp"

mv "$tmp" "$file"
