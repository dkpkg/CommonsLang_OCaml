#!/bin/sh
set -eu

file=$1
vs17='            17.*) autodetect_compiler_vsdev_CMAKEGENERATOR="Visual Studio 17 2022";;'
vs18='            18.*) autodetect_compiler_vsdev_CMAKEGENERATOR="Visual Studio 17 2022";;'
mktemp_old='    WORK=$(PATH=/usr/bin:/bin mktemp -d "$DKML_TMP_PARENTDIR"/dkmlw.XXXXX)'
mktemp_new='    WORK=$(PATH=/usr/bin:/bin mktemp -d -p "$DKML_TMP_PARENTDIR" dkmlw.XXXXXX)'
install_parent_old='    [ ! -e "$DKML_TMP_PARENTDIR" ] && install -d "$DKML_TMP_PARENTDIR"'
install_parent_new='    [ ! -e "$DKML_TMP_PARENTDIR" ] && mkdir -p "$DKML_TMP_PARENTDIR"'
install_work_old='    install -d "$WORK"'
install_work_new='    mkdir -p "$WORK"'
compiler_tmp_darwin_old='        autodetect_compiler_TEMPDIR=$(PATH=/usr/bin:/bin mktemp -d "$_CS_DARWIN_USER_TEMP_DIR"/dkmlc.XXXXX)'
compiler_tmp_darwin_new='        autodetect_compiler_TEMPDIR=$(PATH=/usr/bin:/bin mktemp -d -p "$_CS_DARWIN_USER_TEMP_DIR" dkmlc.XXXXXX)'
compiler_tmp_tmpdir_old='        autodetect_compiler_TEMPDIR=$(PATH=/usr/bin:/bin mktemp -d "$autodetect_compiler_TEMPDIR"/dkmlc.XXXXX)'
compiler_tmp_tmpdir_new='        autodetect_compiler_TEMPDIR=$(PATH=/usr/bin:/bin mktemp -d -p "$autodetect_compiler_TEMPDIR" dkmlc.XXXXXX)'
compiler_tmp_tmp_old='        autodetect_compiler_TEMPDIR=$(PATH=/usr/bin:/bin mktemp -d "$TMP"/dkmlc.XXXXX)'
compiler_tmp_tmp_new='        autodetect_compiler_TEMPDIR=$(PATH=/usr/bin:/bin mktemp -d -p "$TMP" dkmlc.XXXXXX)'
compiler_tmp_default_old='        autodetect_compiler_TEMPDIR=$(PATH=/usr/bin:/bin mktemp -d /tmp/dkmlc.XXXXX)'
compiler_tmp_default_new='        autodetect_compiler_TEMPDIR=$(PATH=/usr/bin:/bin mktemp -d -p /tmp dkmlc.XXXXXX)'
cpus_tmp_darwin_old='            autodetect_cpus_TEMPDIR=$(mktemp -d "$_CS_DARWIN_USER_TEMP_DIR"/dkmlcpu.XXXXX)'
cpus_tmp_darwin_new='            autodetect_cpus_TEMPDIR=$(mktemp -d -p "$_CS_DARWIN_USER_TEMP_DIR" dkmlcpu.XXXXXX)'
cpus_tmp_tmpdir_old='            autodetect_cpus_TEMPDIR=$(mktemp -d "$autodetect_cpus_TEMPDIR"/dkmlcpu.XXXXX)'
cpus_tmp_tmpdir_new='            autodetect_cpus_TEMPDIR=$(mktemp -d -p "$autodetect_cpus_TEMPDIR" dkmlcpu.XXXXXX)'
cpus_tmp_tmp_old='            autodetect_cpus_TEMPDIR=$(mktemp -d "$TMP"/dkmlcpu.XXXXX)'
cpus_tmp_tmp_new='            autodetect_cpus_TEMPDIR=$(mktemp -d -p "$TMP" dkmlcpu.XXXXXX)'
cpus_tmp_default_old='            autodetect_cpus_TEMPDIR=$(mktemp -d /tmp/dkmlcpu.XXXXX)'
cpus_tmp_default_new='            autodetect_cpus_TEMPDIR=$(mktemp -d -p /tmp dkmlcpu.XXXXXX)'
busybox_old='    elif [ -x /bin/busybox ]; then'
busybox_new='    elif [ -x /bin/busybox ] || command -v busybox.exe >/dev/null 2>&1 || command -v busybox >/dev/null 2>&1; then'
exec_script_old='        printf "  exec %s " \'
exec_script_new='        printf "  exec bash %s " \'
vsdev_export='    export VSDEV_CMAKEGENERATOR='
vsdev_direct='    if [ -n "${DKML_COMPILE_VS_DIR:-}" ]; then'
vc_req_1425='                -requires Microsoft.VisualStudio.Component.VC.14.25.x86.x64 \'
vc_req_1426='                -requires Microsoft.VisualStudio.Component.VC.14.26.x86.x64 \'
vc_req_1429='                -requires Microsoft.VisualStudio.Component.VC.14.29.x86.x64 \'
vc_requires_any='                -requiresAny \'
awk_dump_pattern_old="                '/^MS(VS|VS64)_(NAME|PATH|INC|LIB|ML)=/{print}'"
grep_dump_new='            printf "  set | grep -E '\''^MS(VS|VS64)_(NAME|PATH|INC|LIB|ML)='\'';;\n"'

tmp="$file.tmp"
done_insert=
have_vs18=
skip_awk_pattern=
{
    while IFS= read -r line || [ -n "$line" ]; do
        if [ -n "$skip_awk_pattern" ]; then
            skip_awk_pattern=
            if [ "$line" = "$awk_dump_pattern_old" ]; then
                continue
            fi
        fi
        if [ "$line" = "$vs18" ]; then
            have_vs18=1
        fi
        if [ "$line" = "$mktemp_old" ]; then
            printf '%s\n' "$mktemp_new"
            continue
        fi
        if [ "$line" = "$install_parent_old" ]; then
            printf '%s\n' "$install_parent_new"
            continue
        fi
        if [ "$line" = "$install_work_old" ]; then
            printf '%s\n' "$install_work_new"
            continue
        fi
        if [ "$line" = "$compiler_tmp_darwin_old" ]; then
            printf '%s\n' "$compiler_tmp_darwin_new"
            continue
        fi
        if [ "$line" = "$compiler_tmp_tmpdir_old" ]; then
            printf '%s\n' "$compiler_tmp_tmpdir_new"
            continue
        fi
        if [ "$line" = "$compiler_tmp_tmp_old" ]; then
            printf '%s\n' "$compiler_tmp_tmp_new"
            continue
        fi
        if [ "$line" = "$compiler_tmp_default_old" ]; then
            printf '%s\n' "$compiler_tmp_default_new"
            continue
        fi
        if [ "$line" = "$cpus_tmp_darwin_old" ]; then
            printf '%s\n' "$cpus_tmp_darwin_new"
            continue
        fi
        if [ "$line" = "$cpus_tmp_tmpdir_old" ]; then
            printf '%s\n' "$cpus_tmp_tmpdir_new"
            continue
        fi
        if [ "$line" = "$cpus_tmp_tmp_old" ]; then
            printf '%s\n' "$cpus_tmp_tmp_new"
            continue
        fi
        if [ "$line" = "$cpus_tmp_default_old" ]; then
            printf '%s\n' "$cpus_tmp_default_new"
            continue
        fi
        if [ "$line" = "$busybox_old" ]; then
            printf '%s\n' "$busybox_new"
            continue
        fi
        if [ "$line" = "$vsdev_export" ]; then
            printf '%s\n' "$line"
            printf '%s\n' '    if [ -n "${DKML_COMPILE_VS_DIR:-}" ]; then'
            printf '%s\n' '        VSDEV_HOME_UNIX="$DKML_COMPILE_VS_DIR"'
            printf '%s\n' '        if [ -x /usr/bin/cygpath ]; then'
            printf '%s\n' '            VSDEV_HOME_BUILDHOST=$(/usr/bin/cygpath -aw "$VSDEV_HOME_UNIX")'
            printf '%s\n' '        else'
            printf '%s\n' '            VSDEV_HOME_BUILDHOST="$VSDEV_HOME_UNIX"'
            printf '%s\n' '        fi'
            printf '%s\n' '        VSDEV_VCVARSVER="${DKML_COMPILE_VS_VCVARSVER:-}"'
            printf '%s\n' '        VSDEV_WINSDKVER="${DKML_COMPILE_VS_WINSDKVER:-}"'
            printf '%s\n' '        VSDEV_MSVSPREFERENCE="${DKML_COMPILE_VS_MSVSPREFERENCE:-}"'
            printf '%s\n' '        VSDEV_CMAKEGENERATOR="${DKML_COMPILE_VS_CMAKEGENERATOR:-}"'
            printf '%s\n' '        return 0'
            printf '%s\n' '    fi'
            continue
        fi
        if [ "$line" = "$vc_req_1425" ] || [ "$line" = "$vc_req_1426" ] || [ "$line" = "$vc_req_1429" ] || [ "$line" = "$vc_requires_any" ]; then
            continue
        fi
        if [ "$line" = "$exec_script_old" ]; then
            printf '%s\n' "$exec_script_new"
            continue
        fi
        case $line in
        *"set | awk "*)
            printf '%s\n' "$grep_dump_new"
            skip_awk_pattern=1
            continue
            ;;
        esac
        printf '%s\n' "$line"
        if [ -z "${have_vs18}" ] && [ -z "${done_insert}" ] && [ "$line" = "$vs17" ]; then
            printf '%s\n' "$vs18"
            done_insert=1
        fi
    done < "$file"
} > "$tmp"

grep -F "$vs18" "$tmp" >/dev/null 2>&1
grep -F "$mktemp_new" "$tmp" >/dev/null 2>&1
grep -F "$install_parent_new" "$tmp" >/dev/null 2>&1
grep -F "$install_work_new" "$tmp" >/dev/null 2>&1
grep -F "$compiler_tmp_tmp_new" "$tmp" >/dev/null 2>&1
grep -F "$cpus_tmp_tmp_new" "$tmp" >/dev/null 2>&1
grep -F "$busybox_new" "$tmp" >/dev/null 2>&1
grep -F "$exec_script_new" "$tmp" >/dev/null 2>&1
grep -F "$grep_dump_new" "$tmp" >/dev/null 2>&1
grep -F "$vsdev_direct" "$tmp" >/dev/null 2>&1
mv "$tmp" "$file"
