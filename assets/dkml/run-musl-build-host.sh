#!/bin/sh
# ----------------------------
# Copyright 2026 Diskuv, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ----------------------------
#
# Wrapper that runs r-c-ocaml-2-build_host for the Release.Linux_x86_64_musl
# DkML slot with the x86_64-linux-musl cross toolchain bin prepended to the
# *process* PATH.
#
# Why this wrapper exists: build_host runs OCaml's ./configure via
# ocaml_configure, which resolves the bare compiler name (x86_64-linux-musl-gcc)
# against the process PATH -- NOT the hermetic make PATH that DK_UNIX_ESSENTIALS
# feeds, and NOT reliably via the compiler launcher's PATH binding. Without the
# cross bin on the process PATH, configure fails with
#   configure: error: C compiler cannot create executables
#   ./configure: line NNNN: x86_64-linux-musl-gcc: command not found
# The musl `-k` env script's `export_binding PATH` only sets the launcher's
# PATH, and a plain `export PATH` there runs too deep (inside autodetect) to
# reach configure. Setting it here, in the build command's own shell, does
# reach configure and every child of this build. The tools stay bare-named so
# `ocamlc -config` remains relocatable.
#
# DKML_MUSL_BINDIR (the absolute bin/ of the extracted cross toolchain) is
# supplied by the DkML.Unix musl build command's environment.
set -eu

if [ -z "${DKML_MUSL_BINDIR:-}" ]; then
  echo "FATAL: DKML_MUSL_BINDIR is not set for run-musl-build-host.sh" >&2
  exit 107
fi

# Expose the bare-named cross tools where OCaml's ./configure will find them.
# build_host runs ./configure via ocaml_configure, whose compiler launcher
# (with-host-c-compiler.sh) restores a system PATH before exec-ing configure --
# so neither DK_UNIX_ESSENTIALS (which feeds only the hermetic make PATH) nor a
# plain PATH export here reaches the conftest, and configure fails
#   configure: error: C compiler cannot create executables
#   ./configure: line NNNN: x86_64-linux-musl-gcc: command not found
# /usr/local/bin is always on that restored PATH, so symlink the cross tools
# into it. autoconf caches the bare tool NAME (ac_cv_prog_CC=x86_64-linux-musl-gcc),
# not the resolved path, so ocamlc -config stays relocatable; and each real gcc
# still finds its sibling as/ld relative to its own toolchain location. make is
# unaffected -- it uses the hermetic PATH that DK_UNIX_ESSENTIALS extends.
if [ -d /usr/local/bin ]; then
  for _t in "$DKML_MUSL_BINDIR"/x86_64-linux-musl-*; do
    [ -e "$_t" ] || continue
    ln -sf "$_t" "/usr/local/bin/$(basename "$_t")" 2>/dev/null || true
  done
fi

# Also prepend to this process's PATH (harmless belt-and-braces for any
# direct-PATH lookups before the launcher is built).
PATH="$DKML_MUSL_BINDIR:$PATH"
export PATH

exec /bin/sh share/dkml/repro/100co/vendor/dkml-compiler/src/r-c-ocaml-2-build_host-noargs.sh
