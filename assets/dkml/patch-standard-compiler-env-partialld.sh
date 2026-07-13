#!/bin/sh
set -eu

# Make the DkML Unix relocatable OCaml compiler's `native_pack_linker` config
# setting relocatable.
#
# `./configure` bakes Config.native_pack_linker from DIRECT_LD as a static
# string. On the Unix host that string becomes an absolute, build-host-only path
# (e.g. .../src-ocaml/support/with-host-c-compiler.sh.ld64.sh), so `ocamlopt
# -pack` fails on any machine other than the one that built the compiler.
# `standard_library` avoids this because it is recomputed at runtime relative to
# the executable; native_pack_linker has no such runtime relocation.
#
# Fix: preset PARTIALLD to a PATH-relative `ld` (keeping any per-target
# -melf_i386 / -arch flags DIRECT_LD already carries). ./configure honors a
# preset PARTIALLD verbatim (PACKLD="$PARTIALLD -o"), so native_pack_linker
# becomes `<ld> ...flags... -r -o`, which resolves on the user's PATH -- exactly
# what the Base (mingw) lane already ships. Unix (linux_*/darwin_*) only; the
# Windows/MSVC lane already bakes a resolvable linker.

file=$1
tmp="$file.tmp"
found=0

{
    while IFS= read -r line || [ -n "$line" ]; do
        printf '%s\n' "$line"
        if [ "$line" = 'export_binding DIRECT_LD "${DIRECT_LD:-}"' ]; then
            found=1
            printf '%s\n' 'case "${DKML_TARGET_ABI:-}" in'
            printf '%s\n' '  linux_*|darwin_*)'
            printf '%s\n' '    if [ -n "${DIRECT_LD:-}" ]; then'
            printf '%s\n' '      _partialld_exe=${DIRECT_LD%% *}'
            printf '%s\n' '      _partialld_rest=${DIRECT_LD#"$_partialld_exe"}'
            printf '%s\n' '      export_binding PARTIALLD "${_partialld_exe##*/}${_partialld_rest} -r"'
            printf '%s\n' '    fi'
            printf '%s\n' '    ;;'
            printf '%s\n' 'esac'
        fi
    done < "$file"
} > "$tmp"

if [ "$found" = 0 ]; then
    rm -f "$tmp"
    printf '%s\n' "patch-standard-compiler-env-partialld.sh: anchor 'export_binding DIRECT_LD \"\${DIRECT_LD:-}\"' not found in $file" >&2
    exit 1
fi

mv "$tmp" "$file"
