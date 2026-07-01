#!/bin/sh
# Stub replacement for opam's shell/msvs-detect.
#
# opam's real msvs-detect is a 1100+ line bash-4 script (associative arrays,
# ${!var} indirection, ${var,,}) that DETECTS a Visual Studio install. It cannot
# run under BusyBox-w32 sh/ash (stack overflow), and detection is unnecessary
# when the build already runs inside an activated MSVC environment (vcvars): cl
# is on PATH and INCLUDE / LIB are set. Emit the MSVS_* contract that opam's
# ./configure eval's from this script's stdout. Under the BusyBox-w32 toolchain
# PATH is Windows-style (C:/...) with PATH_SEPARATOR=';', so MSVS_PATH is emitted
# Windows-style ending in ';' (not the cygwin colon-path the real script emits).
_cl=$(which cl 2>/dev/null)
_cldir=$(dirname "$_cl" 2>/dev/null)
_cldir_win=$(cygpath -m "$_cldir" 2>/dev/null || printf '%s' "$_cldir")
printf "MSVS_NAME='DkML MSVC'\n"
printf "MSVS_PATH='%s;'\n" "$_cldir_win"
printf "MSVS_INC='%s;'\n" "${INCLUDE%;}"
printf "MSVS_LIB='%s;'\n" "${LIB%;}"
printf "MSVS_ML='ml64.exe'\n"
