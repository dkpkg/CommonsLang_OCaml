#!/bin/sh
set -eu

file=$1
tmp="$file.tmp"

emit_unix_to_buildhost_case() {
    indent=$1
    source_var=$2
    target_var=$3
    printf '%s%s%s%s\n' "$indent" '    _dkml_vs_source=$(printf "%s" "$' "$source_var" '" | tr -d "\r")'
    printf '%s%s\n' "$indent" 'case "$_dkml_vs_source" in'
    printf '%s%s\n' "$indent" '    /cygdrive/*)'
    printf '%s%s\n' "$indent" '        _dkml_vs_path=${_dkml_vs_source#/cygdrive/}'
    printf '%s%s\n' "$indent" '        _dkml_vs_drive=${_dkml_vs_path%%/*}'
    printf '%s%s\n' "$indent" '        _dkml_vs_rest=${_dkml_vs_path#*/}'
    printf '%s%s\n' "$indent" '        _dkml_vs_drive_upper=$(printf "%s" "$_dkml_vs_drive" | tr "[:lower:]" "[:upper:]")'
    printf '%s%s%s%s\n' "$indent" '        ' "$target_var" '=$(printf "%s:/%s" "$_dkml_vs_drive_upper" "$_dkml_vs_rest")'
    printf '%s%s\n' "$indent" '        ;;'
    printf '%s%s\n' "$indent" '    /[A-Za-z]/*)'
    printf '%s%s\n' "$indent" '        _dkml_vs_path=${_dkml_vs_source#/}'
    printf '%s%s\n' "$indent" '        _dkml_vs_drive=${_dkml_vs_path%%/*}'
    printf '%s%s\n' "$indent" '        _dkml_vs_rest=${_dkml_vs_path#*/}'
    printf '%s%s\n' "$indent" '        _dkml_vs_drive_upper=$(printf "%s" "$_dkml_vs_drive" | tr "[:lower:]" "[:upper:]")'
    printf '%s%s%s%s\n' "$indent" '        ' "$target_var" '=$(printf "%s:/%s" "$_dkml_vs_drive_upper" "$_dkml_vs_rest")'
    printf '%s%s\n' "$indent" '        ;;'
    printf '%s%s\n' "$indent" '    *)'
    printf '%s%s%s%s\n' "$indent" '        ' "$target_var" '="$_dkml_vs_source"'
    printf '%s%s\n' "$indent" '        ;;'
    printf '%s%s\n' "$indent" 'esac'
}

{
    while IFS= read -r line || [ -n "$line" ]; do
        if [ "$line" = '    } > "$autodetect_compiler_TEMPDIR"/vsdevcmd-and-printenv.bat' ]; then
            printf '%s\n' '    autodetect_compiler_TEMPDIR_MIXED=$(printf "%s" "$autodetect_compiler_TEMPDIR_WIN" | "$DKMLSYS_SED" '\''s#\\#/#g'\'')'
            printf '%s\n' '    } > "$autodetect_compiler_TEMPDIR_MIXED"/vsdevcmd-and-printenv.bat'
            continue
        fi
        if [ "$line" = '        printf "@+: %s/vsdevcmd-and-printenv.bat\n" "$autodetect_compiler_TEMPDIR" >&2' ]; then
            printf '%s\n' '        printf "@+: %s/vsdevcmd-and-printenv.bat\n" "$autodetect_compiler_TEMPDIR_MIXED" >&2'
            continue
        fi
        if [ "$line" = '        "$DKMLSYS_SED" '\''s/^/@+| /'\'' "$autodetect_compiler_TEMPDIR"/vsdevcmd-and-printenv.bat | "$DKMLSYS_AWK" '\''{print}'\'' >&2' ]; then
            printf '%s\n' '        "$DKMLSYS_SED" '\''s/^/@+| /'\'' "$autodetect_compiler_TEMPDIR_MIXED"/vsdevcmd-and-printenv.bat | "$DKMLSYS_AWK" '\''{print}'\'' >&2'
            continue
        fi
        if [ "$line" = '            rm -f "$autodetect_compiler_TEMPDIR"/vcvars.txt' ]; then
            printf '%s\n' '            rm -f "$autodetect_compiler_TEMPDIR_MIXED"/vcvars.txt'
            continue
        fi
        if [ "$line" = '                "$autodetect_compiler_TEMPDIR"/vsdevcmd-and-printenv.bat \' ]; then
            printf '%s\n' '                "$autodetect_compiler_TEMPDIR_MIXED"/vsdevcmd-and-printenv.bat \'
            continue
        fi
        if [ "$line" = '            if [ ! -e "$autodetect_compiler_TEMPDIR"/vcvars.txt ]; then ' ]; then
            printf '%s\n' '            if [ ! -e "$autodetect_compiler_TEMPDIR_MIXED"/vcvars.txt ]; then '
            continue
        fi
        if [ "$line" = '                if [ ! "$autodetect_compiler_SPECBITS" = "1234" ]; then' ]; then
            printf '%s\n' '                if [ ! "$autodetect_compiler_SPECBITS" = "1234" ] && [ ! "$autodetect_compiler_SPECBITS" = "124" ]; then'
            continue
        fi
        if [ "$line" = '    $DKMLSYS_CHMOD +x "$autodetect_compiler_TEMPDIR"/vsdevcmd-and-printenv.bat' ]; then
            printf '%s\n' '    # +x is only required for Cygwin; the Windows host shell can execute the batch file as-is.'
            printf '%s\n' '    if is_cygwin_build_machine; then'
            printf '%s\n' '        $DKMLSYS_CHMOD +x "$autodetect_compiler_TEMPDIR"/vsdevcmd-and-printenv.bat'
            printf '%s\n' '    fi'
            continue
        fi
        if [ "$line" = '    if [ -x /usr/bin/cygpath ]; then' ]; then
            IFS= read -r next1 || next1=
            case "$next1" in
                '        VSDEV_HOME_BUILDHOST=$(/usr/bin/cygpath -aw "$VSDEV_HOME_UNIX")')
                    IFS= read -r next2 || next2=
                    IFS= read -r next3 || next3=
                    if [ "$next2" = '    else' ] && [ "$next3" = '        VSDEV_HOME_BUILDHOST="$VSDEV_HOME_UNIX"' ]; then
                        IFS= read -r next4 || next4=
                        [ "$next4" = '    fi' ]
                        emit_unix_to_buildhost_case '    ' 'VSDEV_HOME_UNIX' 'VSDEV_HOME_BUILDHOST'
                        continue
                    fi
                    printf '%s\n%s\n%s\n%s\n%s\n' "$line" "$next1" "$next2" "$next3" "$next4"
                    continue
                    ;;
                '        autodetect_compiler_vsdev_INSTALLDIR_BUILDHOST=$(/usr/bin/cygpath -aw "$autodetect_compiler_vsdev_INSTALLDIR_UNIX")')
                    IFS= read -r next2 || next2=
                    IFS= read -r next3 || next3=
                    IFS= read -r next4 || next4=
                    IFS= read -r next5 || next5=
                    if [ "$next2" = '        autodetect_compiler_vsdev_INSTALLDIR_UNIX=$(/usr/bin/cygpath -au "$autodetect_compiler_vsdev_INSTALLDIR_UNIX")' ] && [ "$next3" = '    else' ] && [ "$next4" = '        autodetect_compiler_vsdev_INSTALLDIR_BUILDHOST="$autodetect_compiler_vsdev_INSTALLDIR_UNIX"' ]; then
                        [ "$next5" = '    fi' ]
                        emit_unix_to_buildhost_case '    ' 'autodetect_compiler_vsdev_INSTALLDIR_UNIX' 'autodetect_compiler_vsdev_INSTALLDIR_BUILDHOST'
                        continue
                    fi
                    printf '%s\n%s\n%s\n%s\n%s\n%s\n' "$line" "$next1" "$next2" "$next3" "$next4" "$next5"
                    continue
                    ;;
                '        autodetect_compiler_VSDEVCMDFILE_WIN=$(/usr/bin/cygpath -aw "$autodetect_compiler_vsdev_VSDEVCMD")')
                    IFS= read -r next2 || next2=
                    IFS= read -r next3 || next3=
                    if [ "$next2" = '    else' ] && [ "$next3" = '        autodetect_compiler_VSDEVCMDFILE_WIN="$autodetect_compiler_vsdev_VSDEVCMD"' ]; then
                        IFS= read -r next4 || next4=
                        [ "$next4" = '    fi' ]
                        emit_unix_to_buildhost_case '    ' 'autodetect_compiler_vsdev_VSDEVCMD' 'autodetect_compiler_VSDEVCMDFILE_WIN'
                        continue
                    fi
                    printf '%s\n%s\n%s\n%s\n%s\n' "$line" "$next1" "$next2" "$next3" "$next4"
                    continue
                    ;;
                *)
                    printf '%s\n%s\n' "$line" "$next1"
                    continue
                    ;;
            esac
        fi
        printf '%s\n' "$line"
    done < "$file"
} > "$tmp"

grep -F '_dkml_vs_source=$(printf "%s" "$VSDEV_HOME_UNIX" | tr -d "\r")' "$tmp" >/dev/null 2>&1
grep -F 'autodetect_compiler_VSDEVCMDFILE_WIN=$(printf "%s:/%s" "$_dkml_vs_drive_upper" "$_dkml_vs_rest")' "$tmp" >/dev/null 2>&1
mv "$tmp" "$file"
