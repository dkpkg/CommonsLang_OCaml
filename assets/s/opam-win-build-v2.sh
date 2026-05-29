#!/bin/sh
set -eu

mode=$1
lookup=$2
base_bin=$3
dune_bin=$4
tool_bin=$5

PATH="$lookup;$tool_bin;$PATH"
export PATH

OCAMLC="$base_bin/ocamlc.exe"
OCAML="$base_bin/ocaml.exe"
OCAMLDEP="$base_bin/ocamldep.exe"
OCAMLMKTOP="$base_bin/ocamlmktop.exe"
OCAMLMKLIB="$base_bin/ocamlmklib.exe"
DUNE="$dune_bin/dune.exe"
CC="$tool_bin/x86_64-w64-mingw32-gcc.exe"
AWK="$tool_bin/awk.exe"
export OCAMLC OCAML OCAMLDEP OCAMLMKTOP OCAMLMKLIB DUNE CC AWK

case "$mode" in
  configure)
    prefix=$6
    MAKE=make ./configure --with-vendored-deps --disable-checks --prefix="$prefix"
    ;;
  build)
    make opam
    ;;
  *)
    echo "unknown mode: $mode" >&2
    exit 64
    ;;
esac
