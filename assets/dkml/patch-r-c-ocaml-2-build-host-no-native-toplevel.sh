#!/bin/sh
# Turn off the native toplevel (ocamlnat) in dkml-compiler's host build:
# r-c-ocaml-2-build_host.sh adds --enable-native-toplevel to OCaml's
# configure for 4.14 and 5.x. DkML and DkMLStatic ship no ocamlnat.
set -eu

file=$1
tmp="$file.tmp"
found=0

{
    while IFS= read -r line || [ -n "$line" ]; do
        if [ "$line" = '            CONFIGUREARGS="$CONFIGUREARGS --enable-native-toplevel"' ]; then
            printf '%s\n' '            : # no native toplevel (CommonsLang_OCaml)'
            found=1
            continue
        fi
        printf '%s\n' "$line"
    done < "$file"
    if [ "$found" -ne 1 ]; then
        echo "patch-r-c-ocaml-2-build-host-no-native-toplevel: no --enable-native-toplevel line in $file" >&2
        exit 1
    fi
} > "$tmp"

# Write back in place so the script keeps its mode (it may be run directly).
cat "$tmp" > "$file"
rm -f "$tmp"
