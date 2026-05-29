#!/bin/sh
set -eu

mode=$1
lookup=$2
base_bin=$3
dune_bin=$4
tool_bin=$5

PATH="$("$lookup/cygpath" -u "$lookup"):$("$lookup/cygpath" -u "$tool_bin")"
export PATH

OCAMLC="$("$lookup/cygpath" -u "$base_bin/ocamlc.exe")"
OCAML="$("$lookup/cygpath" -u "$base_bin/ocaml.exe")"
OCAMLDEP="$("$lookup/cygpath" -u "$base_bin/ocamldep.exe")"
OCAMLMKTOP="$("$lookup/cygpath" -u "$base_bin/ocamlmktop.exe")"
OCAMLMKLIB="$("$lookup/cygpath" -u "$base_bin/ocamlmklib.exe")"
DUNE="$("$lookup/cygpath" -u "$dune_bin/dune.exe")"
export OCAMLC OCAML OCAMLDEP OCAMLMKTOP OCAMLMKLIB DUNE

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
