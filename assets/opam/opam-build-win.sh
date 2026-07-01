#!/bin/sh
# Build opam 2.5.1 off the DkML MSVC OCaml on Windows.
#
# Runs inside an activated MSVC environment (vcvars, set up by the calling bat)
# with DkML's ocaml, Dune and the W64dev tools (sh/make/awk) plus a cygpath shim
# on PATH. The build root contains s/ (the extracted opam source).
#
# Args: $1=output bin dir  $2=msvs-detect stub  $3=mccs glp_write_lp stub
#       $4=install prefix  $5=symlink-free menhir tar (dk0-provided, verified)
set -eu

outbin=$1
msvs_stub=$2
mccs_stub=$3
prefix=$4
menhir_tar=$5

# DkML's ocaml toolchain (on PATH via the dk0 envmod).
od=$(dirname "$(which ocaml)")
export OCAMLC="$od/ocamlc.exe"
export OCAML="$od/ocaml.exe"
export OCAMLDEP="$od/ocamldep.exe"
export OCAMLMKTOP="$od/ocamlmktop.exe"
export OCAMLMKLIB="$od/ocamlmklib.exe"
DUNE=$(which dune); export DUNE
AWK=$(which awk); export AWK
SHELL=$(which sh); export SHELL
export MAKESHELL="$SHELL"
# BusyBox-w32 toolchain: Windows-style ;-separated PATH, and autoconf must try
# the .exe extension when searching PATH for cl / ocamlopt / ...
export PATH_SEPARATOR=';'
export ac_executable_extensions='.exe'

# opam's real shell/msvs-detect is bash-4 and overflows BusyBox-w32 ash; the MSVC
# environment is already active, so replace it with a stub that reports it.
cp "$msvs_stub" s/shell/msvs-detect

# opam downloads menhir, whose tarball carries demo symlinks that Windows tar
# cannot create. dk0 provides the symlink-free menhir (a plain tar whose checksum
# it has already verified); gzip it as opam expects and update opam's recorded
# MD5 so src_ext accepts it instead of re-downloading the original.
cp "$menhir_tar" s/src_ext/menhir.tar
gzip -nf s/src_ext/menhir.tar
menhir_md5=$(md5sum s/src_ext/menhir.tar.gz | cut -d' ' -f1)
sed -i "s/^MD5_menhir = .*/MD5_menhir = $menhir_md5/" s/src_ext/Makefile.sources

# configure (downloads + extracts the vendored deps; the sanitized menhir
# extracts cleanly).
( cd s && ./configure --with-vendored-deps --disable-checks --prefix="$prefix" )

# mccs's vendored glpk omits wrmip.c (glp_write_lp); provide the unused symbol.
cp "$mccs_stub" s/src_ext/mccs/src/glpk/api/wrmip.c
sed -i "s/;;  wrmip/  wrmip/" s/src_ext/mccs/src/glpk/dune

# Build opam.exe only. Building opam-installer.exe trips Windows' UAC-by-name
# heuristic during man-page generation, and that executable is not needed.
( cd s && "$DUNE" build --profile=release --root . opam.install )

cp s/_build/install/default/bin/opam.exe "$outbin/opam.exe"
