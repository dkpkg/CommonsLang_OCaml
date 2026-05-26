#!/bin/sh
set -eu

if test -d src-ocaml; then
  chmod -R u+w src-ocaml
fi
rm -rf src-ocaml share/dkml run-build-host-with-make-win.sh cleanup-dkml-slot.sh
