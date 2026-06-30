#!/bin/sh
set -eu

file=$1
tmp="$file.tmp"

{
    while IFS= read -r line || [ -n "$line" ]; do
        line=${line//| PATH=\/usr\/bin:\/bin grep/| grep}
        line=${line//| PATH=\/usr\/bin:\/bin sed/| sed}
        # Quote the path in the BusyBox-w32 [for %I in (...)] short-path lookups so
        # a Visual Studio under [C:\Program Files (x86)\...] does not break cmd.exe
        # ("/Microsoft was unexpected at this time"). Idempotent: only the unquoted
        # form matches, so a fixed dkml-compiler release leaves these untouched.
        line=${line//for %I in (\$autodetect_compiler_AS) do/for %I in (\"\$autodetect_compiler_AS\") do}
        line=${line//for %I in (\$autodetect_compiler_CC) do/for %I in (\"\$autodetect_compiler_CC\") do}
        line=${line//for %I in (\$autodetect_compiler_CXX) do/for %I in (\"\$autodetect_compiler_CXX\") do}
        line=${line//for %I in (\$autodetect_compiler_LD) do/for %I in (\"\$autodetect_compiler_LD\") do}
        line=${line//for %I in (\$_gnu_as_compiler) do/for %I in (\"\$_gnu_as_compiler\") do}
        if [ "$line" = '    CFLAGS_MSVC="${autodetect_compiler_CFLAGS}"    ' ]; then
            printf '%s\n' '    # VS 2026 / MSVC 19.50 warns on mixed enum comparisons in OCaml 4.14 runtime code.'
            printf '%s\n' '    CFLAGS_MSVC="${autodetect_compiler_CFLAGS:+$autodetect_compiler_CFLAGS }/Wv:18"'
        else
            printf '%s\n' "$line"
        fi
    done < "$file"
} > "$tmp"

mv "$tmp" "$file"
