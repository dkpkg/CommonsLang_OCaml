#!/bin/sh
# Give every macOS compile and assemble a deployment target, so the compiler,
# its runtime (libasmrun.a, libcamlrun.a) and everything it later compiles
# declare macOS 15.0 (LC_BUILD_VERSION minos) instead of the build machine's
# SDK version. The flag goes into CC because OCaml's configure records CC in
# Makefile.config, and mksharedlib and mkexe use CC but not CFLAGS.
set -eu

file=$1
tmp="$file.tmp"
min='-mmacosx-version-min=15.0'

sed \
    -e "s|autodetect_compiler_CC -arch arm64\"|autodetect_compiler_CC -arch arm64 $min\"|" \
    -e "s|autodetect_compiler_CC -arch x86_64\"|autodetect_compiler_CC -arch x86_64 $min\"|" \
    -e "s|autodetect_compiler_ASFLAGS=\"-arch arm64\\\${|autodetect_compiler_ASFLAGS=\"-arch arm64 $min\${|" \
    -e "s|autodetect_compiler_ASFLAGS=\"-arch x86_64\\\${|autodetect_compiler_ASFLAGS=\"-arch x86_64 $min\${|" \
    "$file" > "$tmp"

# The CMake and the plain branches each set CC and ASFLAGS for both chips: 8 lines.
count=$(grep -c -e "$min" "$tmp" || true)
if [ "$count" -ne 8 ]; then
    echo "patch-standard-compiler-env-macos-min: expected 8 patched lines in $file, found $count" >&2
    rm -f "$tmp"
    exit 1
fi

mv "$tmp" "$file"
