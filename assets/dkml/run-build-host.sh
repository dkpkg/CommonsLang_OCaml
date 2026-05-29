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

# Create a minimal cygpath wrapper for W64dev which lacks /usr/bin/cygpath.
# Implements the subset used by dkml-runtime-common crossplatform-functions.sh.
_cygpath_sh="$shell_bin_dir/cygpath"
if [ ! -x "$_cygpath_sh" ]; then
  "$shell_bin_dir/busybox.exe" cp "$shell_bin_dir/busybox.exe" "$_cygpath_sh"
  {
    printf '#!%s/sh.exe\n' "$shell_bin_dir"
    cat << 'CYGEOF'
# Minimal cygpath: W64dev has no native /usr/bin/cygpath.
# Windows path -> Unix (cygdrive) format, one path per call:
_w2u() {
  "$DKMLSYS_AWK" 'BEGIN{ORS="";while((getline l)>0){gsub(/\r/,"",l);if(l~/^[A-Za-z]:/){d=tolower(substr(l,1,1));r=substr(l,3);gsub(/\\/,"/",r);printf"/cygdrive/%s%s",d,r}else{printf"%s",l}};print""}'
}
# Semicolon-separated Windows PATH -> colon-separated Unix PATH:
_wpath2u() {
  "$DKMLSYS_AWK" 'BEGIN{while((getline l)>0){gsub(/\r/,"",l);n=split(l,a,";");s="";for(i=1;i<=n;i++){e=a[i];if(e~/^[A-Za-z]:/){d=tolower(substr(e,1,1));r=substr(e,3);gsub(/\\/,"/",r);printf"%s/cygdrive/%s%s",s,d,r}else{printf"%s%s",s,e};s=":"};printf"\n"}}'
}
_towin() { "$DKMLSYS_AWK" '{gsub(/^\/cygdrive\//,"");d=substr($0,1,1);r=substr($0,2);gsub(/\//,"\\",r);printf"%s:%s\n",toupper(d),r}'; }
_tomixed() { "$DKMLSYS_AWK" '{gsub(/^\/cygdrive\//,"");d=substr($0,1,1);r=substr($0,2);printf"%s:%s\n",toupper(d),r}'; }
case "$1" in
  --sysdir)
    printf '%s/System32' "${SYSTEMROOT:-${WINDIR:-C:/Windows}}" | _w2u; printf '\n' ;;
  --windir)
    printf '%s' "${SYSTEMROOT:-${WINDIR:-C:/Windows}}" | _w2u; printf '\n' ;;
  --folder)
    case "${2:-38}" in
      38) printf '%s' "${PROGRAMFILES:-C:/Program Files}" | _w2u; printf '\n' ;;
      42) printf 'C:\Program Files (x86)' | _w2u; printf '\n' ;;
      *) printf 'cygpath: --folder %s not supported\n' "$2" >&2; exit 1 ;;
    esac ;;
  --path)
    case "$2,$3" in
      -f,-) _wpath2u ;;         # --path -f - : read from stdin
      *) printf '%s' "$2" | _wpath2u ;;  # --path WINPATH : argument
    esac ;;
  -au|-a)
    printf '%s' "$2" | _w2u; printf '\n' ;;
  -aw|-ad|-d)
    printf '%s' "$2" | _towin ;;
  -am)
    printf '%s' "$2" | _tomixed ;;
  -w)
    if [ "${2:-}" = "--path" ]; then
      # -w --path ARG: convert Unix colon-sep PATH to Windows semicolon-sep
      printf '%s' "${3:-}" | "$DKMLSYS_AWK" 'BEGIN{ORS=""}{n=split($0,a,":");for(i=1;i<=n;i++){e=a[i];gsub(/^\/cygdrive\//,"",e);d=substr(e,1,1);r=substr(e,2);gsub(/\//,"\\",r);if(i>1)printf";";printf"%s:%s",toupper(d),r};printf"\n"}'
    else
      printf '%s' "$2" | _towin
    fi ;;
  *)
    printf 'cygpath: unsupported args: %s\n' "$*" >&2; exit 1 ;;
esac
CYGEOF
  } > "$_cygpath_sh"
fi
DKMLSYS_CYGPATH="$_cygpath_sh"
export DKMLSYS_CYGPATH

MAKE=${MAKE_EXE:-}
if [ -n "$MAKE" ] && [ -x "${DKMLSYS_CYGPATH:-/usr/bin/cygpath}" ]; then
  MAKE=$("${DKMLSYS_CYGPATH:-/usr/bin/cygpath}" -au "$MAKE")
fi
if [ -n "$MAKE" ]; then
  export MAKE
fi

vsenv_powershell=
detect_vsenv_ps1=${DKML_DETECT_VSENV_PS1:-${1:-detect-vsenv.ps1}}
for vsenv_candidate in \
  '/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe' \
  '/cygdrive/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe'
do
  if [ -x "$vsenv_candidate" ]; then
    vsenv_powershell=$vsenv_candidate
    break
  fi
done

if [ -n "$vsenv_powershell" ] && [ -f "$detect_vsenv_ps1" ] && [ -z "${VSINSTALLDIR:-}" ]; then
  while IFS= read -r vsenv_line || [ -n "$vsenv_line" ]; do
    case "$vsenv_line" in
      *=*) export "$vsenv_line" ;;
    esac
  done <<EOF
$("$vsenv_powershell" -NoProfile -ExecutionPolicy Bypass -File "$detect_vsenv_ps1" | "$shell_bin_dir/tr.exe" -d '\r')
EOF
fi

if [ -n "${DKML_COMPILE_VS_DIR:-}" ]; then
  unset WindowsSDKVersion
  unset DKML_COMPILE_VS_WINSDKVER
  export DKML_COMPILE_SPEC=1
  export DKML_COMPILE_TYPE=VS
fi

if [ -x "${DKMLSYS_CYGPATH:-/usr/bin/cygpath}" ]; then
  : "${CFLAGS_MSVC:=/Wv:18}"
  export CFLAGS_MSVC
fi

: "${NUMCPUS:=1}"
export NUMCPUS

if [ -f src-ocaml/msvs-detect ]; then
  "$shell_bin_dir/sed.exe" -i "s#  set | awk '/^MS(VS|VS64)_(NAME|PATH|INC|LIB|ML)=/{print}';;#  set | grep -E '^MS(VS|VS64)_(NAME|PATH|INC|LIB|ML)=';;#" src-ocaml/msvs-detect
fi

# Fix dkml-runtime-common crossplatform-functions.sh: autodetect_compiler_TEMPDIR_MIXED
# is assigned inside a { } group but used as the redirect target for that same group.
# In POSIX sh, the redirect is evaluated before the group body executes, so the variable
# must be assigned BEFORE the { opener.
_drc_cf=share/dkml/repro/100co/vendor/drc/unix/crossplatform-functions.sh
if [ -f "$_drc_cf" ] && "$DKMLSYS_GREP" -qF 'TEMPDIR_MIXED=$(printf' "$_drc_cf"; then
  # Step 1: remove the assignment from inside the group
  "$DKMLSYS_SED" -i '/autodetect_compiler_TEMPDIR_MIXED=\$(printf.*DKMLSYS_SED/d' "$_drc_cf"
  # Step 2: re-insert BEFORE the { that opens the group; the only esac→{ sequence in
  # the function is the unique marker for that group.
  "$DKMLSYS_AWK" '
/^    esac$/ {
    if ((getline line) > 0) {
        print
        if (line ~ /^    \{$/) {
            print "    autodetect_compiler_TEMPDIR_MIXED=$(printf \"%s\" \"$autodetect_compiler_TEMPDIR_WIN\" | \"$DKMLSYS_SED\" '"'"'s#\\\\#/#g'"'"')"
        }
        print line
        next
    }
}
{ print }
' "$_drc_cf" > "$_drc_cf.new" && "$DKMLSYS_MV" "$_drc_cf.new" "$_drc_cf"
fi

if [ -f "$_drc_cf" ] && "$DKMLSYS_GREP" -qF '/usr/bin/cygpath' "$_drc_cf"; then
  "$DKMLSYS_SED" -i 's#/usr/bin/cygpath#${DKMLSYS_CYGPATH:-/usr/bin/cygpath}#g' "$_drc_cf"
fi

host_noargs='share/dkml/repro/100co/vendor/dkml-compiler/src/r-c-ocaml-2-build_host-noargs.sh'
if [ -f "$host_noargs" ]; then
  "$shell_bin_dir/sed.exe" -i 's#exec bash #exec "$BASH" #g' "$host_noargs"
  request_dir=$(pwd)
  "$shell_bin_dir/sed.exe" -i "s#-d share/dkml/repro/100co -t \\.#-d $request_dir/share/dkml/repro/100co -t $request_dir#g" "$host_noargs"
fi

exec "$BASH" "$host_noargs"
