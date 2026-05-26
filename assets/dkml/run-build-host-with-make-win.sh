#!/bin/sh
set -eu

MAKE=$(/usr/bin/cygpath -au "$MAKE_WIN")
export MAKE

: "${CFLAGS_MSVC:=/Wv:18}"
export CFLAGS_MSVC

: "${NUMCPUS:=1}"
export NUMCPUS

exec share/dkml/repro/100co/vendor/dkml-compiler/src/r-c-ocaml-2-build_host-noargs.sh
