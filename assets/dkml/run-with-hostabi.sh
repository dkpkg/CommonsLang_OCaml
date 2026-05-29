#!/bin/sh
set -eu

reloc_flags='--with-relative-libdir=../lib/ocaml --enable-runtime-search --enable-runtime-search-target=fallback'

case " ${DKML_HOST_OCAML_CONFIGURE-} " in
  *" --with-relative-libdir="*) ;;
  *) DKML_HOST_OCAML_CONFIGURE="${DKML_HOST_OCAML_CONFIGURE:+$DKML_HOST_OCAML_CONFIGURE }$reloc_flags" ;;
esac
export DKML_HOST_OCAML_CONFIGURE

hostabi_file=$1
shift

hostabi=
IFS= read -r hostabi < "$hostabi_file" || [ -n "$hostabi" ]
exec "$@" "-e$hostabi"
