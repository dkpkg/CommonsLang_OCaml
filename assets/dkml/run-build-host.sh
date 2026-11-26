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

# MSVC C runtime. DKML_MSVC_CRT selects one of two consistent builds:
#
#   dynamic (the default; CommonsLang_OCaml.DkML) compiles every C object /MD
#   and links every image against the DLL C runtime. FlexDLL's Makefile also
#   compiles its objects /MD, and flexlink adds msvcrt.lib to every link.
#
#   static (CommonsLang_OCaml.DkMLStatic) compiles every C object /MT,
#   FlexDLL's objects included, and links every image against the static C
#   runtime. The file that DKML_NOFLEXDLL_STUB names takes the place of the
#   FlexDLL runtime source, and the executables carry no dynamic loader. On
#   x64 every image gets a preferred base address above 4 GB.
#
# CFLAGS_MSVC takes the place of the `-O2 -MD` that OCaml's configure puts in
# OC_CFLAGS (dkml-compiler patch ocaml-common-4_14-b05-msvccflags), and it
# carries the optimization and C runtime flags itself. dkml-compiler computes
# CFLAGS_MSVC only for a CMake MSVC compiler spec; this Visual Studio build
# takes the default below. /Wv:18 keeps the MSVC 19.50 warning baseline, and
# -WX stays usable on the OCaml 4.14 runtime sources.
dkml_msvc_crt=${DKML_MSVC_CRT:-dynamic}
case "$dkml_msvc_crt" in
  dynamic) : "${CFLAGS_MSVC:=-O2 -MD /Wv:18}" ;;
  static) : "${CFLAGS_MSVC:=-O2 -MT /Wv:18}" ;;
  *)
    printf 'FATAL: DKML_MSVC_CRT must be dynamic or static, not "%s"\n' "$dkml_msvc_crt" >&2
    exit 1
    ;;
esac
export CFLAGS_MSVC

dkml_fatal() {
  printf 'FATAL: %s\n' "$*" >&2
  exit 1
}

# Rewrite FILE through an awk PROGRAM; any further arguments go to awk first.
# The awk program exits nonzero when the line it rewrites is missing.
dkml_rewrite() {
  _dkml_rewrite_file=$1
  shift
  hermetic_util chmod u+w "$_dkml_rewrite_file"
  if hermetic_util awk "$@" "$_dkml_rewrite_file" > "$_dkml_rewrite_file.new"; then
    hermetic_util mv "$_dkml_rewrite_file.new" "$_dkml_rewrite_file"
  else
    hermetic_util rm -f "$_dkml_rewrite_file.new"
    dkml_fatal "could not rewrite $_dkml_rewrite_file for DKML_MSVC_CRT=$dkml_msvc_crt"
  fi
}

# flexlink options for every DkMLStatic link (executables, DLLs and .cmxs):
#   -custom-crt        drops the msvcrt.lib that flexlink adds and tells link.exe
#                      /nodefaultlib:LIBCMT /nodefaultlib:MSVCRT
#   -defaultlib LIB    names each static C runtime library; flexlink resolves
#                      C runtime symbols against them and passes them to link.exe
#   -base ADDR         preferred image base, from DKML_STATIC_IMAGE_BASE, which
#                      only the x64 form sets (0x140000000, above 4 GB);
#                      flexlink honours -base on x64 only, so x86 keeps the
#                      default 0x400000
# They go into FLEXLINK_FLAGS in Makefile.config, which OCaml bakes into
# `ocamlopt -config`'s mkexe, mkdll and mkmaindll. Every executable that a
# DkMLStatic ocamlopt or ocamlc -custom links gets them with no extra flags.
dkml_static_flexlink_flags="-custom-crt${DKML_STATIC_IMAGE_BASE:+ -base $DKML_STATIC_IMAGE_BASE} -defaultlib libcmt.lib -defaultlib libvcruntime.lib -defaultlib libucrt.lib -defaultlib oldnames.lib"

if [ "$dkml_msvc_crt" = static ]; then
  if [ -z "${DKML_NOFLEXDLL_STUB:-}" ] || [ ! -f "$DKML_NOFLEXDLL_STUB" ]; then
    dkml_fatal "DKML_MSVC_CRT=static needs DKML_NOFLEXDLL_STUB to name noflexdll-stub.c"
  fi
  _dkml_flexdir=src-ocaml/flexdll
  if [ ! -f "$_dkml_flexdir/flexdll.c" ] || [ ! -f "$_dkml_flexdir/Makefile" ]; then
    dkml_fatal "no FlexDLL sources in $_dkml_flexdir"
  fi

  # The FlexDLL runtime object (flexdll_msvc.obj, flexdll_msvc64.obj) becomes
  # the stub. flexlink links it into every executable.
  hermetic_util chmod u+w "$_dkml_flexdir/flexdll.c"
  hermetic_util rm -f "$_dkml_flexdir/flexdll.c"
  hermetic_util cp "$DKML_NOFLEXDLL_STUB" "$_dkml_flexdir/flexdll.c"

  # FlexDLL compiles its objects with MSVC_FLAGS=/nologo /MD ...
  dkml_rewrite "$_dkml_flexdir/Makefile" '
    /^MSVC_FLAGS=/ { sub(/ \/MD /, " /MT "); if ($0 ~ / \/MT /) found = 1 }
    { print }
    END { if (!found) exit 3 }
  '

  for _dkml_mc in src-ocaml/Makefile.config.in src-ocaml/Makefile.config; do
    if [ -f "$_dkml_mc" ]; then
      dkml_rewrite "$_dkml_mc" -v extra="$dkml_static_flexlink_flags" '
        /^FLEXLINK_FLAGS=/ {
          found = 1
          if (index($0, "-custom-crt") == 0) $0 = $0 " " extra
        }
        { print }
        END { if (!found) exit 3 }
      '
    fi
  done
  if [ ! -f src-ocaml/Makefile.config.in ]; then
    dkml_fatal "no src-ocaml/Makefile.config.in to carry the DkMLStatic flexlink flags"
  fi
fi

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

# Build log and warning scan. The OCaml build runs with its output copied to
# share/dkml/repro/dkml-build.log, which cleanup-dkml-slot.sh removes with the
# rest of share/dkml/repro. These warnings fail the build:
#
#   D9025    cl overrode one option with another (for example /MD with /MT)
#   D9002    cl ignored an unknown option
#   LNK4098  a default library conflicts with the other C runtime libraries
#   LNK4217  an object imports a symbol that another object defines locally,
#   LNK4286  as an object compiled /MD does in a static C runtime link
#   LNK4281  an x64 image has a base address below 4 GB (DkMLStatic only)
#
# DkML allows LNK4281. flexlink gives every x64 image /base:0x10000, which
# keeps a program and the DLLs that FlexDLL loads within 32-bit relative
# reach of each other.
#
# flexlink discards link.exe's output when the link succeeds. A warning from
# a flexlink link reaches the log only when that link fails. The audit
# after the scan reads the installed images instead: it checks the C runtime
# that each library and object names, and for DkMLStatic the DLLs that each
# image imports and the x64 image base.
dkml_log_dir=share/dkml/repro
build_log="$dkml_log_dir/dkml-build.log"
build_status_file="$dkml_log_dir/dkml-build.status"
hermetic_util mkdir -p "$dkml_log_dir"
hermetic_util rm -f "$build_log" "$build_status_file"
{ sh "$host_noargs" 2>&1 || echo "$?" > "$build_status_file"; } | hermetic_util tee "$build_log"
if [ -s "$build_status_file" ]; then
  build_status=$(hermetic_util cat "$build_status_file")
  printf 'FATAL: the OCaml build failed with exit code %s\n' "$build_status" >&2
  exit "$build_status"
fi

dkml_fatal_warnings='D9025|D9002|LNK4098|LNK4217|LNK4286'
if [ "$dkml_msvc_crt" = static ]; then
  dkml_fatal_warnings="$dkml_fatal_warnings|LNK4281"
fi
_dkml_rc=0
hermetic_util grep -E -i "warning ($dkml_fatal_warnings)" "$build_log" > "$build_log.hits" || _dkml_rc=$?
case "$_dkml_rc" in
  0)
    printf 'FATAL: the OCaml build printed warnings that mean wrong compile or link flags:\n' >&2
    hermetic_util cat "$build_log.hits" >&2
    exit 1
    ;;
  1) ;;
  *) dkml_fatal "could not scan $build_log (grep exit code $_dkml_rc)" ;;
esac
printf 'INFO: no %s warnings in the OCaml build log\n' "$dkml_fatal_warnings" >&2

# C runtime audit with dumpbin from the Visual Studio installation that
# detect-vsenv.bat found. DKML_SKIP_CRT_AUDIT=1 skips it.
dkml_find_dumpbin() {
  _dkml_vs=$(printf '%s' "${VSINSTALLDIR:-}" | hermetic_util tr '\\' '/')
  _dkml_vs=${_dkml_vs%/}
  if [ -z "$_dkml_vs" ] || [ -z "${VCToolsVersion:-}" ]; then
    return 1
  fi
  for _dkml_host in Hostx64/x64 Hostx86/x86 HostARM64/arm64; do
    _dkml_dumpbin="$_dkml_vs/VC/Tools/MSVC/$VCToolsVersion/bin/$_dkml_host/dumpbin.exe"
    if [ -f "$_dkml_dumpbin" ]; then
      printf '%s\n' "$_dkml_dumpbin"
      return 0
    fi
  done
  return 1
}

dkml_audit_failed=0
dkml_audit_error() {
  printf 'FATAL: %s\n' "$*" >&2
  dkml_audit_failed=1
}

if [ "${DKML_SKIP_CRT_AUDIT:-0}" = 1 ]; then
  printf 'WARNING: DKML_SKIP_CRT_AUDIT=1; the C runtime audit is skipped\n' >&2
else
  if ! dumpbin=$(dkml_find_dumpbin); then
    dkml_fatal "dumpbin.exe not found for VSINSTALLDIR=${VSINSTALLDIR:-} VCToolsVersion=${VCToolsVersion:-}; DKML_SKIP_CRT_AUDIT=1 skips the C runtime audit"
  fi
  if ! "$dumpbin" /nologo /headers bin/ocamlrun.exe | hermetic_util tr -d '\r' | hermetic_util grep -q 'FILE HEADER VALUES'; then
    dkml_fatal "$dumpbin could not read bin/ocamlrun.exe"
  fi

  # Each C library or object may name only the C runtime of this build.
  case "$dkml_msvc_crt" in
    dynamic) dkml_wrong_crt='LIBCMTD?' ;;
    static) dkml_wrong_crt='MSVCRTD?' ;;
  esac
  hermetic_util find bin lib -type f '(' -name '*.lib' -o -name '*.obj' ')' > "$dkml_log_dir/dkml-audit-libs.txt"
  while IFS= read -r _dkml_f; do
    if "$dumpbin" /nologo /directives "$_dkml_f" | hermetic_util tr -d '\r' |
        hermetic_util grep -q -i -E "/DEFAULTLIB:\"?$dkml_wrong_crt(\\.lib)?\"?([^A-Za-z0-9]|\$)"; then
      dkml_audit_error "$_dkml_f names the C runtime library $dkml_wrong_crt"
    fi
  done < "$dkml_log_dir/dkml-audit-libs.txt"

  if [ "$dkml_msvc_crt" = static ]; then
    # DkMLStatic is configured --disable-shared: nothing it builds loads a DLL.
    if ! hermetic_util grep -q -x 'SUPPORTS_SHARED_LIBRARIES=false' lib/ocaml/Makefile.config; then
      dkml_audit_error "lib/ocaml/Makefile.config does not say SUPPORTS_SHARED_LIBRARIES=false"
    fi
    hermetic_util find bin lib -type f '(' -name '*.exe' -o -name '*.dll' ')' > "$dkml_log_dir/dkml-audit-images.txt"
    while IFS= read -r _dkml_f; do
      # No image may import the DLL C runtime.
      if "$dumpbin" /nologo /dependents "$_dkml_f" | hermetic_util tr -d '\r' |
          hermetic_util grep -i -E '^[[:space:]]+(vcruntime[0-9_]*|msvcp[0-9_]*|msvcr[0-9]*|ucrtbased?|api-ms-win-crt-[a-z0-9-]*)\.dll[[:space:]]*$' > "$dkml_log_dir/dkml-audit-hits.txt"; then
        dkml_audit_error "$_dkml_f imports the DLL C runtime: $(hermetic_util tr -s ' \n' ' ' < "$dkml_log_dir/dkml-audit-hits.txt")"
      fi
      # Every x64 executable has a preferred base address above 4 GB.
      case "$_dkml_f" in
        *.exe)
          "$dumpbin" /nologo /headers "$_dkml_f" | hermetic_util tr -d '\r' > "$dkml_log_dir/dkml-audit-headers.txt"
          if hermetic_util grep -q -i 'machine (x64)' "$dkml_log_dir/dkml-audit-headers.txt"; then
            _dkml_base=$(hermetic_util awk '/ image base / { print $1; exit }' "$dkml_log_dir/dkml-audit-headers.txt" | hermetic_util sed 's/^0*//')
            if [ -z "$_dkml_base" ] || [ "${#_dkml_base}" -le 8 ]; then
              dkml_audit_error "$_dkml_f has the x64 image base 0x$_dkml_base, below 4 GB"
            fi
          fi
          ;;
      esac
    done < "$dkml_log_dir/dkml-audit-images.txt"
  fi

  if [ "$dkml_audit_failed" != 0 ]; then
    dkml_fatal "the C runtime audit failed for DKML_MSVC_CRT=$dkml_msvc_crt"
  fi
  printf 'INFO: the C runtime audit passed for DKML_MSVC_CRT=%s\n' "$dkml_msvc_crt" >&2
fi
