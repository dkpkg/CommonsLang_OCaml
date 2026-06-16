#!/bin/sh
set -eu

if test -d src-ocaml; then
  chmod -R u+w src-ocaml
fi
# Drop the debug (ocamlrund) and instrumented (ocamlruni) runtime executables,
# including their runtime-search-versioned variants; they are not needed in the
# distributed toolchain.
rm -f bin/*ocamlrund*.exe bin/*ocamlruni*.exe
rm -rf src-ocaml share/dkml/repro run-build-host.sh detect-vsenv.bat cleanup-dkml-slot.sh
