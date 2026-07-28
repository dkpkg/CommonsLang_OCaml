#!/bin/sh
# Dispatch to the bundled x86_64-linux-musl cross tool matching this script's
# name. Installed as bin/x86_64-linux-musl-<tool> in the
# Release.Linux_x86_64_musl DkML slot; the real toolchain lives in the
# sibling x86_64-linux-musl-cross/ tree of the same slot, so the baked bare
# tool names in `ocamlc -config` resolve wherever the slot's bin/ is on PATH.
d=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
exec "$d/../x86_64-linux-musl-cross/bin/$(basename -- "$0")" "$@"
