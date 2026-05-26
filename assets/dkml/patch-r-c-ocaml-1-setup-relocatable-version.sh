#!/bin/sh
set -eu

file=$1
tmp="$file.tmp"

{
    while IFS= read -r line; do
        if [ "$line" = '            PATCHES+=("$DKMLDIR/$line")' ]; then
            printf '%s\n' '            if should_apply_patch "$line"; then'
            printf '%s\n' '                PATCHES+=("$DKMLDIR/$line")'
            printf '%s\n' '            fi'
            continue
        fi
        if [ "$line" = '    git -C "$verify_applied_patches_SRCDIR" \' ]; then
            printf '%s\n' '    git -C "$verify_applied_patches_SRCDIR_MIXED" \'
            continue
        fi
        printf '%s\n' "$line"
        if [ "$line" = '    set_version_stems_VER=$1' ]; then
            printf '%s\n' '    set_version_stems_VER=${set_version_stems_VER%%+*}'
            printf '%s\n' '    set_version_stems_VER=${set_version_stems_VER%%~*}'
        fi
        if [ "$line" = '    verify_applied_patches_ACTUAL="$WORK/actual-patch-subjects"' ]; then
            printf '%s\n' '    verify_applied_patches_SRCDIR_MIXED="$verify_applied_patches_SRCDIR"'
            printf '%s\n' '    if [ -x /usr/bin/cygpath ]; then'
            printf '%s\n' '        verify_applied_patches_SRCDIR_MIXED=$(/usr/bin/cygpath -aw "$verify_applied_patches_SRCDIR_MIXED")'
            printf '%s\n' '    fi'
        fi
        if [ "$line" = '    PATCHES=()' ]; then
            printf '%s\n' '    should_apply_patch() {'
            printf '%s\n' '        case "$(basename "$1")" in'
            printf '%s\n' '            ocaml-common-4_14-b06-linearclosures.patch)'
            printf '%s\n' '                if [ "$set_patches_CATEGORY" = "ocaml" ] && [ "$set_patches_VER" = "4.14.3" ]; then'
            printf '%s\n' '                    return 1'
            printf '%s\n' '                fi'
            printf '%s\n' '                ;;'
            printf '%s\n' '        esac'
            printf '%s\n' '        return 0'
            printf '%s\n' '    }'
        fi
    done < "$file"
} > "$tmp"

mv "$tmp" "$file"
