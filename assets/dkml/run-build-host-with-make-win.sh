#!/bin/sh
set -eu

shell_bin_dir=$(cd ../../c/shell-bin/bin && pwd)
export shell_bin_dir

git_path=
for git_dir in \
  '/cygdrive/c/Program Files/Git/cmd' \
  '/cygdrive/c/Program Files (x86)/Git/cmd' \
  "$HOME/scoop/apps/git/current/cmd"
do
  if [ -x "$git_dir/git.exe" ]; then
    git_path=$git_dir
    break
  fi
done

DKMLSYS_MV="$shell_bin_dir/mv.exe"
DKMLSYS_CHMOD="$shell_bin_dir/chmod.exe"
DKMLSYS_UNAME="$shell_bin_dir/uname.exe"
DKMLSYS_ENV="$shell_bin_dir/env.exe"
DKMLSYS_AWK="$shell_bin_dir/awk.exe"
DKMLSYS_SED="$shell_bin_dir/sed.exe"
DKMLSYS_COMM="$shell_bin_dir/comm.exe"
DKMLSYS_INSTALL="$shell_bin_dir/install"
DKMLSYS_RM="$shell_bin_dir/rm.exe"
DKMLSYS_SORT="$shell_bin_dir/sort.exe"
DKMLSYS_CAT="$shell_bin_dir/cat.exe"
DKMLSYS_STAT="$shell_bin_dir/stat.exe"
DKMLSYS_GREP="$shell_bin_dir/grep.exe"
DKMLSYS_CURL="$shell_bin_dir/curl.exe"
DKMLSYS_WGET="$shell_bin_dir/wget.exe"
DKMLSYS_TR="$shell_bin_dir/tr.exe"
export DKMLSYS_MV DKMLSYS_CHMOD DKMLSYS_UNAME DKMLSYS_ENV DKMLSYS_AWK DKMLSYS_SED
export DKMLSYS_COMM DKMLSYS_INSTALL DKMLSYS_RM DKMLSYS_SORT DKMLSYS_CAT DKMLSYS_STAT
export DKMLSYS_GREP DKMLSYS_CURL DKMLSYS_WGET DKMLSYS_TR

# Windows UAC compatibility heuristic blocks execution of install.exe (and setup.exe,
# update.exe, patch.exe, etc.) for non-elevated processes. Work around by creating a
# shell script named 'install' (no .exe extension = no UAC trigger). Copy an existing
# executable first so the file inherits executable permissions, then overwrite with
# the script body.
"$shell_bin_dir/busybox.exe" cp "$shell_bin_dir/grep.exe" "$shell_bin_dir/install"
printf '#!%s/sh.exe\nexec "%s/busybox.exe" install "$@"\n' "$shell_bin_dir" "$shell_bin_dir" > "$shell_bin_dir/install"

PATH="$shell_bin_dir"
if [ -n "$git_path" ]; then
  PATH="$PATH:$git_path"
fi
export PATH

MAKE=${MAKE_EXE:-${MAKE_WIN:-}}
if [ -n "$MAKE" ] && [ -x /usr/bin/cygpath ]; then
  MAKE=$(/usr/bin/cygpath -au "$MAKE")
fi
if [ -n "$MAKE" ]; then
  export MAKE
fi

vsenv_powershell=
for vsenv_candidate in \
  '/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe' \
  '/cygdrive/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe'
do
  if [ -x "$vsenv_candidate" ]; then
    vsenv_powershell=$vsenv_candidate
    break
  fi
done

if [ -n "$vsenv_powershell" ] && [ -f detect-vsenv.ps1 ] && [ -z "${VSINSTALLDIR:-}" ]; then
  while IFS= read -r vsenv_line || [ -n "$vsenv_line" ]; do
    case "$vsenv_line" in
      *=*) export "$vsenv_line" ;;
    esac
  done <<EOF
$("$vsenv_powershell" -NoProfile -ExecutionPolicy Bypass -File detect-vsenv.ps1 | "$shell_bin_dir/tr.exe" -d '\r')
EOF
fi

if [ -n "${DKML_COMPILE_VS_DIR:-}" ]; then
  unset WindowsSDKVersion
  unset DKML_COMPILE_VS_WINSDKVER
  export DKML_COMPILE_SPEC=1
  export DKML_COMPILE_TYPE=VS
fi

if [ -x /usr/bin/cygpath ]; then
  : "${CFLAGS_MSVC:=/Wv:18}"
  export CFLAGS_MSVC
fi

: "${NUMCPUS:=1}"
export NUMCPUS

if [ -f src-ocaml/msvs-detect ]; then
  "$shell_bin_dir/sed.exe" -i "s#  set | awk '/^MS(VS|VS64)_(NAME|PATH|INC|LIB|ML)=/{print}';;#  set | grep -E '^MS(VS|VS64)_(NAME|PATH|INC|LIB|ML)=';;#" src-ocaml/msvs-detect
fi

host_noargs='share/dkml/repro/100co/vendor/dkml-compiler/src/r-c-ocaml-2-build_host-noargs.sh'
if [ -f "$host_noargs" ]; then
  "$shell_bin_dir/sed.exe" -i 's#exec bash #exec "$BASH" #g' "$host_noargs"
  request_dir=$(pwd)
  "$shell_bin_dir/sed.exe" -i "s#-d share/dkml/repro/100co -t \\.#-d $request_dir/share/dkml/repro/100co -t $request_dir#g" "$host_noargs"
fi

exec "$BASH" "$host_noargs"
