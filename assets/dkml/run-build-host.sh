#!/bin/sh
set -eu

detect_vsenv_bat=$1
shift

original_path=${PATH:-}

if [ -n "${MAKE_WIN:-}" ]; then
  shell_bin_dir=$(cd "$(dirname "$MAKE_WIN")" && pwd)
else
  shell_bin_dir=/usr/bin
fi

# Windows UAC compatibility heuristic blocks execution of install.exe (and setup.exe,
# update.exe, patch.exe, etc.) for non-elevated processes. Work around by creating a
# shell script named 'install' (no .exe extension = no UAC trigger). Copy an existing
# executable first so the file inherits executable permissions, then overwrite with
# the script body.
# if [ -n "${COMSPEC:-}" ]; then
#   "$shell_bin_dir/busybox.exe" cp "$shell_bin_dir/grep.exe" "$shell_bin_dir/install"
#   printf '#!%s/sh.exe\nexec "%s/busybox.exe" install "$@"\n' "$shell_bin_dir" "$shell_bin_dir" > "$shell_bin_dir/install"
# fi

# Deprecated DKMLSYS_* variables are intentionally not set.
# DKMLSYS_MV="$shell_bin_dir/mv.exe"
# DKMLSYS_CHMOD="$shell_bin_dir/chmod.exe"
# DKMLSYS_UNAME="$shell_bin_dir/uname.exe"
# DKMLSYS_ENV="$shell_bin_dir/env.exe"
# DKMLSYS_AWK="$shell_bin_dir/awk.exe"
# DKMLSYS_SED="$shell_bin_dir/sed.exe"
# DKMLSYS_COMM="$shell_bin_dir/comm.exe"
# DKMLSYS_INSTALL="$shell_bin_dir/install"
# DKMLSYS_RM="$shell_bin_dir/rm.exe"
# DKMLSYS_SORT="$shell_bin_dir/sort.exe"
# DKMLSYS_CAT="$shell_bin_dir/cat.exe"
# DKMLSYS_STAT="$shell_bin_dir/stat.exe"
# DKMLSYS_GREP="$shell_bin_dir/grep.exe"
# DKMLSYS_CURL="$shell_bin_dir/curl.exe"
# DKMLSYS_WGET="$shell_bin_dir/wget.exe"
# DKMLSYS_TR="$shell_bin_dir/tr.exe"

PATH="$shell_bin_dir"

# Prepend the hermetic UnixEssentials bin so subprocesses that look up tools on
# PATH directly -- OCaml's ./configure and build-aux/config.guess -- find real
# GNU sed/awk/grep instead of the W64dev busybox applets, which OCaml configure
# rejects ("no acceptable sed could be found in $PATH").
if [ -n "${DK_UNIX_ESSENTIALS:-}" ] && [ -d "$DK_UNIX_ESSENTIALS/bin" ]; then
  essentials_bin_dir=$(cd "$DK_UNIX_ESSENTIALS/bin" && pwd)
  PATH="$essentials_bin_dir:$shell_bin_dir"
fi
export PATH

# OCaml's ./configure (autoconf) honors a pre-set PATH_SEPARATOR -- see the
# "The user is always right" block in configure. On Windows under BusyBox-w32
# there is no cygpath, so the build PATH stays semicolon-separated with Windows
# drive-letter entries (e.g. "Y:/a/bin;Y:/b/bin"). autoconf's own probe is
# fooled (':' is a shell builtin that needs no PATH lookup), so it defaults to
# ':' and shatters every drive-letter entry, breaking both AC_PROG_SED ("no
# acceptable sed could be found in $PATH") and build-aux/config.guess. Force
# ';' so configure parses the PATH. Cygwin/MSYS2 keep the autoconf default
# because they provide /usr/bin/cygpath (and use ':').
if [ -n "${COMSPEC:-}" ] && [ ! -x /usr/bin/cygpath ]; then
  PATH_SEPARATOR=';'
  export PATH_SEPARATOR
  # OCaml's ./configure (4.14) never sets ac_executable_extensions, so its
  # program search (AC_PROG_SED, AC_PATH_PROG, ...) only tests "<dir>/<prog>"
  # with no extension. Under BusyBox-w32 the tools are "<prog>.exe", so
  # `test -x <dir>/sed` fails even though sed.exe is on PATH. autoconf appends
  # each ac_executable_extensions entry, so exporting ".exe" makes the search
  # also try "<dir>/<prog>.exe" and find the real tools.
  ac_executable_extensions='.exe'
  export ac_executable_extensions
fi

if [ -z "${DKML_SYSTEM_PATH:-}" ] && [ -n "$original_path" ]; then
  DKML_SYSTEM_PATH="$original_path"
  export DKML_SYSTEM_PATH
fi

find_in_essentials() {
  _find_in_essentials_tool="$1"
  if [ -n "${DK_UNIX_ESSENTIALS:-}" ] && [ -x "$DK_UNIX_ESSENTIALS/bin/$_find_in_essentials_tool.exe" ]; then
    printf '%s\n' "$DK_UNIX_ESSENTIALS/bin/$_find_in_essentials_tool.exe"
    return 0
  fi
  if [ -n "${DK_UNIX_ESSENTIALS:-}" ] && [ -x "$DK_UNIX_ESSENTIALS/bin/$_find_in_essentials_tool" ]; then
    printf '%s\n' "$DK_UNIX_ESSENTIALS/bin/$_find_in_essentials_tool"
    return 0
  fi
  if [ -x "$shell_bin_dir/$_find_in_essentials_tool.exe" ]; then
    printf '%s\n' "$shell_bin_dir/$_find_in_essentials_tool.exe"
    return 0
  fi
  if [ -x "$shell_bin_dir/$_find_in_essentials_tool" ]; then
    printf '%s\n' "$shell_bin_dir/$_find_in_essentials_tool"
    return 0
  fi
  printf '%s\n' "$_find_in_essentials_tool"
}

hermetic_util() {
  _hermetic_util_cmd="$1"
  shift
  case "$_hermetic_util_cmd" in
    awk|find|grep|sed)
      _exe=$(find_in_essentials "$_hermetic_util_cmd")
      "$_exe" "$@"
      ;;
    basename|cat|comm|cp|cut|date|dirname|env|install|mktemp|mv|paste|pwd|rm|sort|stat|touch|tr|uname|wc)
      if [ -n "${DK_UNIX_COREUTILS:-}" ]; then
        "$DK_UNIX_COREUTILS" "$_hermetic_util_cmd" "$@"
      else
        _exe=$(find_in_essentials "$_hermetic_util_cmd")
        "$_exe" "$@"
      fi
      ;;
    *)
      "$_hermetic_util_cmd" "$@"
      ;;
  esac
}

# Create a minimal cygpath wrapper for W64dev which lacks /usr/bin/cygpath.
# Implements the subset used by dkml-runtime-common crossplatform-functions.sh.
# _cygpath_sh="$shell_bin_dir/cygpath"
# if [ ! -x "$_cygpath_sh" ]; then
#   "$shell_bin_dir/busybox.exe" cp "$shell_bin_dir/busybox.exe" "$_cygpath_sh"
#   {
#     printf '#!%s/sh.exe\n' "$shell_bin_dir"
#     cat << 'CYGEOF'
# # Minimal cygpath: W64dev has no native /usr/bin/cygpath.
# # Windows path -> Unix (cygdrive) format, one path per call:
# _w2u() {
#   awk 'BEGIN{ORS="";while((getline l)>0){gsub(/\r/,"",l);if(l~/^[A-Za-z]:/){d=tolower(substr(l,1,1));r=substr(l,3);gsub(/\\/,"/",r);printf"/cygdrive/%s%s",d,r}else{printf"%s",l}};print""}'
# }
# # Semicolon-separated Windows PATH -> colon-separated Unix PATH:
# _wpath2u() {
#   awk 'BEGIN{while((getline l)>0){gsub(/\r/,"",l);n=split(l,a,";");s="";for(i=1;i<=n;i++){e=a[i];if(e~/^[A-Za-z]:/){d=tolower(substr(e,1,1));r=substr(e,3);gsub(/\\/,"/",r);printf"%s/cygdrive/%s%s",s,d,r}else{printf"%s%s",s,e};s=":"};printf"\n"}}'
# }
# _towin() { awk '{gsub(/^\/cygdrive\//,"");d=substr($0,1,1);r=substr($0,2);gsub(/\//,"\\",r);printf"%s:%s\n",toupper(d),r}'; }
# _tomixed() { awk '{gsub(/^\/cygdrive\//,"");d=substr($0,1,1);r=substr($0,2);printf"%s:%s\n",toupper(d),r}'; }
# case "$1" in
#   --sysdir)
#     printf '%s/System32' "${SYSTEMROOT:-${WINDIR:-C:/Windows}}" | _w2u; printf '\n' ;;
#   --windir)
#     printf '%s' "${SYSTEMROOT:-${WINDIR:-C:/Windows}}" | _w2u; printf '\n' ;;
#   --folder)
#     case "${2:-38}" in
#       38) printf '%s' "${PROGRAMFILES:-C:/Program Files}" | _w2u; printf '\n' ;;
#       42) printf 'C:\Program Files (x86)' | _w2u; printf '\n' ;;
#       *) printf 'cygpath: --folder %s not supported\n' "$2" >&2; exit 1 ;;
#     esac ;;
#   --path)
#     case "$2,$3" in
#       -f,-) _wpath2u ;;         # --path -f - : read from stdin
#       *) printf '%s' "$2" | _wpath2u ;;  # --path WINPATH : argument
#     esac ;;
#   -au|-a)
#     printf '%s' "$2" | _w2u; printf '\n' ;;
#   -aw|-ad|-d)
#     printf '%s' "$2" | _towin ;;
#   -am)
#     printf '%s' "$2" | _tomixed ;;
#   -w)
#     if [ "${2:-}" = "--path" ]; then
#       # -w --path ARG: convert Unix colon-sep PATH to Windows semicolon-sep
#       printf '%s' "${3:-}" | awk 'BEGIN{ORS=""}{n=split($0,a,":");for(i=1;i<=n;i++){e=a[i];gsub(/^\/cygdrive\//,"",e);d=substr(e,1,1);r=substr(e,2);gsub(/\//,"\\",r);if(i>1)printf";";printf"%s:%s",toupper(d),r};printf"\n"}'
#     else
#       printf '%s' "$2" | _towin
#     fi ;;
#   *)
#     printf 'cygpath: unsupported args: %s\n' "$*" >&2; exit 1 ;;
# esac
# CYGEOF
#   } > "$_cygpath_sh"
# fi
# DKML_CYGPATH="$_cygpath_sh"
# export DKML_CYGPATH

# Fix install-sh for the OCaml 4.14 host build on Windows. The generated
# Makefile.build_config sets `INSTALL ?= build-aux/install-sh -c -p` -- a
# relative path with no `sh` prefix -- so `make -C runtime install` fails with
# "build-aux/install-sh: not found" (a recursive sub-make cannot find the
# rootdir-relative script, and Windows cannot exec a shell script directly).
# This mirrors assets/s/fix-install-sh.sh (used by the Base lane), but the DkML
# host build runs ./configure and `make install` in one step, so we rewrite the
# source template Makefile.build_config.in (which config.status copies verbatim
# once @INSTALL@ is gone) before configure runs. Result:
#   INSTALL ?= sh.exe $(ROOTDIR)/build-aux/install-sh -c
for _mbc in src-ocaml/Makefile.build_config.in src-ocaml/Makefile.build_config; do
  if [ -f "$_mbc" ]; then
    hermetic_util awk '
      BEGIN { d = sprintf("%c", 36) }
      /^INSTALL \?= (@INSTALL@|(\.\/)?build-aux\/install-sh -c) -p$/ {
        print "INSTALL ?= sh.exe " d "(ROOTDIR)/build-aux/install-sh -c"
        next
      }
      { print }
    ' "$_mbc" > "$_mbc.new" && hermetic_util mv "$_mbc.new" "$_mbc"
  fi
done

MAKE=${MAKE_EXE:-${MAKE_WIN:-}}
if [ -n "$MAKE" ]; then
  export MAKE
fi

vsenv_cmd=${COMSPEC:-cmd.exe}
while IFS= read -r vsenv_line || [ -n "$vsenv_line" ]; do
  case "$vsenv_line" in
    *=*) export "$vsenv_line" ;;
  esac
done <<EOF
$("$vsenv_cmd" /c "$detect_vsenv_bat" | hermetic_util tr -d '\r')
EOF

if [ -n "${DKML_COMPILE_VS_DIR:-}" ]; then
  export DKML_COMPILE_SPEC=1
  export DKML_COMPILE_TYPE=VS
fi

: "${CFLAGS_MSVC:=/Wv:18}"
export CFLAGS_MSVC

: "${NUMCPUS:=1}"
export NUMCPUS

# if [ -f src-ocaml/msvs-detect ]; then
#   hermetic_util sed -i "s#  set | awk '/^MS(VS|VS64)_(NAME|PATH|INC|LIB|ML)=/{print}';;#  set | grep -E '^MS(VS|VS64)_(NAME|PATH|INC|LIB|ML)=';;#" src-ocaml/msvs-detect
# fi

#_drc_cf=share/dkml/repro/100co/vendor/drc/unix/crossplatform-functions.sh
# No TEMPDIR_MIXED patching: current crossplatform-functions.sh has no TEMPDIR_MIXED.
# if [ -f "$_drc_cf" ] && hermetic_util grep -qF 'TEMPDIR_MIXED=$(printf' "$_drc_cf"; then
#   # Step 1: remove the assignment from inside the group
#   hermetic_util sed -i '/autodetect_compiler_TEMPDIR_MIXED=\$(printf.*DKMLSYS_SED/d' "$_drc_cf"
#   # Step 2: re-insert BEFORE the { that opens the group; the only esac→{ sequence in
#   # the function is the unique marker for that group.
#   hermetic_util awk '
# /^    esac$/ {
#     if ((getline line) > 0) {
#         print
#         if (line ~ /^    \{$/) {
#             print "    autodetect_compiler_TEMPDIR_MIXED=$(printf \"%s\" \"$autodetect_compiler_TEMPDIR_WIN\" | sed '"'"'s#\\\\#/#g'"'"')"
#         }
#         print line
#         next
#     }
# }
# { print }
# ' "$_drc_cf" > "$_drc_cf.new" && hermetic_util mv "$_drc_cf.new" "$_drc_cf"
# fi

# No /usr/bin/cygpath rewriting: DKML_CYGPATH is disabled for BusyBox-w32.
# if [ -n "${DKML_CYGPATH:-}" ] && [ -x "$DKML_CYGPATH" ] && [ -f "$_drc_cf" ] && hermetic_util grep -qF '/usr/bin/cygpath' "$_drc_cf"; then
#   hermetic_util sed -i "s#/usr/bin/cygpath#${DKML_CYGPATH}#g" "$_drc_cf"
# fi

# Preserve an explicitly provided DKML_SYSTEM_PATH; do not overwrite it with
# /usr/bin:/bin defaults in BusyBox-w32 environments.
# if [ -f "$_drc_cf" ] && hermetic_util grep -qF 'autodetect_system_path() {' "$_drc_cf"; then
#   hermetic_util sed -i '/^autodetect_system_path() {/a\    [ -n "${DKML_SYSTEM_PATH:-}" ] && return' "$_drc_cf"
# fi
# if [ -f "$_drc_cf" ] && hermetic_util grep -qF '__VSCMD_ARG_NO_LOGO=1' "$_drc_cf"; then
#   hermetic_util sed -i "s#__VSCMD_ARG_NO_LOGO=1 ##g" "$_drc_cf"
# fi

host_noargs='share/dkml/repro/100co/vendor/dkml-compiler/src/r-c-ocaml-2-build_host-noargs.sh'
# if [ -f "$host_noargs" ]; then
#   request_dir=$(pwd)
#   hermetic_util sed -i "s#-d share/dkml/repro/100co -t \\.#-d $request_dir/share/dkml/repro/100co -t '$request_dir'#g" "$host_noargs"
# fi

# Keep temporary paths Windows-friendly for VsDevCmd and mktemp consumers.
if [ -n "${COMSPEC:-}" ]; then
  tmp_parent="${TEMP:-C:/Windows/Temp}"
else
  tmp_parent="$(pwd)/tmp"
fi
hermetic_util mkdir -p "$tmp_parent"
TMPDIR="$tmp_parent"
TEMP="$tmp_parent"
TMP="$tmp_parent"
export TMPDIR TEMP TMP
if [ -n "${COMSPEC:-}" ]; then
  DKML_TMP_PARENTDIR=$(printf '%s' "$tmp_parent" | hermetic_util sed 's#/#\\#g')
  export DKML_TMP_PARENTDIR
fi

exec sh "$host_noargs"
