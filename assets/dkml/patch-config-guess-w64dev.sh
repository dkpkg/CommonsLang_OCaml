#!/bin/sh
set -eu

file=$1
tmp="$file.tmp"
linux_x86_64_case='    linux_x86_64)'
windows_x86_64_case='    windows_x86_64)'
windows_x86_64_body_1='      printf "%s=%s %s=%s" "--host" "x86_64-w64-mingw32" "--target" "x86_64-w64-mingw32"'
windows_x86_64_body_2='      ;;'
windows_x86_case='    windows_x86)'
windows_x86_body_1='      printf "%s=%s %s=%s" "--host" "i686-w64-mingw32" "--target" "i686-w64-mingw32"'
windows_x86_body_2='      ;;'
inserted_windows_cases=

{
    while IFS= read -r line || [ -n "$line" ]; do
        if [ "$line" = '  ocaml_configure_options_for_abi_GUESS=$(build-aux/config.guess)' ]; then
            printf '%s\n' '  case "$ocaml_configure_options_for_abi_ABI" in'
            printf '%s\n' '    windows_x86_64) ocaml_configure_options_for_abi_GUESS=x86_64-w64-mingw32 ;;'
            printf '%s\n' '    windows_x86) ocaml_configure_options_for_abi_GUESS=i686-w64-mingw32 ;;'
            printf '%s\n' '    *) ocaml_configure_options_for_abi_GUESS=$(sh build-aux/config.guess) ;;'
            printf '%s\n' '  esac'
            continue
        fi
        if [ "$line" = '    build_world_HOST_TRIPLET=$("$build_world_BUILD_ROOT"/build-aux/config.guess)' ]; then
            printf '%s\n' '    build_world_HOST_TRIPLET=$(sh "$build_world_BUILD_ROOT"/build-aux/config.guess)'
            continue
        fi
        if [ -z "${inserted_windows_cases}" ] && [ "$line" = "$linux_x86_64_case" ]; then
            printf '%s\n' "$windows_x86_64_case"
            printf '%s\n' "$windows_x86_64_body_1"
            printf '%s\n' "$windows_x86_64_body_2"
            printf '%s\n' "$windows_x86_case"
            printf '%s\n' "$windows_x86_body_1"
            printf '%s\n' "$windows_x86_body_2"
            inserted_windows_cases=1
        fi
        printf '%s\n' "$line"
    done < "$file"
} > "$tmp"

mv "$tmp" "$file"
