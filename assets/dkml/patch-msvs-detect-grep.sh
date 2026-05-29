#!/bin/sh
set -eu

file=$1
tmp="$file.tmp"
skip_regex_line=0

{
    while IFS= read -r line || [ -n "$line" ]; do
        if [ "$skip_regex_line" = 1 ]; then
            skip_regex_line=0
            case "$line" in
                *"/^MS(VS|VS64)_(NAME|PATH|INC|LIB|ML)=/{print}"*)
                    continue
                    ;;
            esac
        fi

        case "$line" in
            *'set | awk '*)
                printf '%s\n' '            printf "  set | grep -E '\''^MS(VS|VS64)_(NAME|PATH|INC|LIB|ML)='\'';;\n"'
                skip_regex_line=1
                continue
                ;;
        esac

        printf '%s\n' "$line"
    done < "$file"
} > "$tmp"

grep -F "set | grep -E '^MS(VS|VS64)_(NAME|PATH|INC|LIB|ML)='" "$tmp" >/dev/null 2>&1
mv "$tmp" "$file"
