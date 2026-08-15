#!/bin/sh
# Dispatch to the host GCC-family tool matching this script's name, adding the
# 32-bit flag that tool needs. Installed as bin/i686-none-linux-gnu-<tool> in
# the Release.Linux_x86 DkML slot.
#
# Unlike the musl wrapper there is no bundled cross tree: the manylinux
# container's own multilib gcc/as/ld ARE the backing tools, and 32-bit comes
# from the flag added here.
#
# Why a wrapper at all, when `gcc -m32` already works: OCaml bakes CC into
# `ocamlc -config` as `c_compiler`, and dune reads that field as a program plus
# arguments, keeps only the program, and re-adds the arguments through its
# `:standard` C flag set (dune's ocaml_config.ml). A package whose dune stanza
# overrides `:standard` -- lwt's `(c_flags -I. (:include unix_c_flags.sexp))` --
# then compiles its C stubs with a bare 64-bit `gcc` while ocamlmklib links
# 32-bit, and ld rejects the objects:
#   ld: i386:x86-64 architecture of input file `...o' is incompatible with
#       i386 output
# Naming the 32-bitness into the PROGRAM removes the argument that could be
# dropped, so every consumer that word-splits c_compiler (dune, ocamlbuild,
# configure+make) stays 32-bit.
#
# Bare-named (resolved through the slot's bin/ on PATH) so the values baked
# into ocamlc -config remain relocatable.
set -eu
t=${0##*/}
case "$t" in
*-gcc) exec gcc -m32 "$@" ;;
*-g++) exec g++ -m32 "$@" ;;
*-as) exec as --32 "$@" ;;
*-ld) exec ld -melf_i386 "$@" ;;
*)
    echo "FATAL: x86-tool-wrapper.sh invoked under an unknown tool name: $t" >&2
    exit 107
    ;;
esac
