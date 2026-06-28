#!/bin/sh
set -eu

if test -d src-ocaml; then
  chmod -R u+w src-ocaml
fi
# Drop the debug (ocamlrund) and instrumented (ocamlruni) runtime executables,
# including their runtime-search-versioned variants; they are not needed in the
# distributed toolchain. The glob has no .exe suffix so it matches both the
# Windows (.exe) and Unix runtime names.
rm -f bin/*ocamlrund* bin/*ocamlruni*

# On Windows the default drivers (e.g. bin/ocamlc.exe) are installed as native
# NTFS symlinks to their .opt.exe variant. Such symlinks dangle once the
# relocatable tree is copied and zipped (the packaging step then cannot open
# e.g. bin/flexlink.exe), and a later step deletes the .opt.exe/.byte.exe
# variants. Replace each default with the real native binary first, then drop
# the redundant variants. The .opt.exe guard makes this a no-op on Unix, where
# symlinks are kept and handled by the archive format.
for base in flexlink ocamlc ocamlcp ocamldep ocamldoc ocamllex ocamlmklib \
            ocamlmktop ocamlobjinfo ocamlopt ocamloptp ocamlprof; do
  if [ -e "bin/$base.opt.exe" ]; then
    rm -f "bin/$base.exe"
    mv -f "bin/$base.opt.exe" "bin/$base.exe"
  fi
  rm -f "bin/$base.byte.exe"
done

rm -rf src-ocaml share/dkml/repro run-build-host.sh detect-vsenv.bat cleanup-dkml-slot.sh
