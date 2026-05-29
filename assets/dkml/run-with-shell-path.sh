#!/bin/sh
set -eu

shell_bin_dir=$1
shift
script_path=$1
shift

case $shell_bin_dir in
  [A-Za-z]:*)
    drive=${shell_bin_dir%:*}
    drive=$(printf '%s' "$drive" | tr 'A-Z' 'a-z')
    rest=${shell_bin_dir#?:}
    rest=${rest//\\//}
    shell_bin_dir=/cygdrive/$drive$rest
    ;;
esac

install() {
  "$shell_bin_dir/busybox.exe" install "$@"
}

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
DKMLSYS_INSTALL=install
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

PATH="$shell_bin_dir"
if [ -n "$git_path" ]; then
  PATH="$PATH:$git_path"
fi
export PATH

. "$script_path" "$@"
