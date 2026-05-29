#!/bin/sh
set -eu

if test -d src-ocaml; then
  chmod -R u+w src-ocaml
fi
rm -rf src-ocaml share/dkml run-build-host.sh run-build-host-with-make-win.sh run-with-hostabi.sh cleanup-dkml-slot.sh
