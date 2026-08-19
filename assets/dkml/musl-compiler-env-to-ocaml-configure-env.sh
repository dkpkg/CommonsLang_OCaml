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
# --post-transform (-k HOSTABISCRIPT) script for the Release.Linux_x86_64_musl
# DkML slot. r-c-ocaml-1-setup requires the -k script to be SELF-CONTAINED,
# because it installs ONLY this file into the reproducible build tree
# (share/dkml/repro/100co/...); it cannot source
# standard-compiler-env-to-ocaml-configure-env.sh (that file is not packaged
# there, so sourcing it fails at r-c-ocaml-2-build_host time). This ABI only
# ever uses the pinned x86_64-linux-musl cross toolchain -- a plain GCC-family
# compiler -- so the standard script's MSVC/Xcode/Android/CMake autodetection
# is irrelevant and the few GCC-family adjustments it makes are inlined here.
#
# On entry autodetect_compiler() has populated autodetect_compiler_* and the
# helper `export_binding NAME VALUE` (adds NAME=VALUE to the launcher env).
# DKML_MUSL_BINDIR is the absolute bin/ of the extracted cross toolchain,
# passed by the DkML.Unix musl build commands.
set -euf

if [ -z "${DKML_MUSL_BINDIR:-}" ]; then
  echo "FATAL: DKML_MUSL_BINDIR is not set for the musl post-transform" >&2
  exit 107
fi

# Put the cross toolchain on PATH for configure/make (and for the baked bare
# tool names to resolve during this build). Consumers of the built compiler
# resolve the same bare names through the slot's bin/x86_64-linux-musl-*
# dispatch wrappers, so ocamlc -config stays relocatable. NOTE: this binding
# alone does not reach OCaml's ./configure -- the DkML.Unix musl build command
# runs r-c-ocaml-2-build_host through run-musl-build-host.sh, which prepends the
# cross bin to the *process* PATH so autoconf resolves the bare CC name.
export_binding PATH "$DKML_MUSL_BINDIR:$PATH"

# Bare GCC-family cross tools. Bare (not absolute) so the values baked into
# ocamlc -config are relocatable. -Wno-format matches the standard script's
# GCC handling; -Os matches the ocaml-option-static musl recipe. LIBS=-static
# (executable links only, never the -shared stublibs) is supplied as a
# ./configure arg via DKML_HOST_OCAML_CONFIGURE, not here.
# -static in CFLAGS (not just LIBS) so it reaches the executable links that
# OCaml's mkexe does not cover -- notably the host bootstrap tool `sak`, which
# is linked with `$(CC) $(CFLAGS) -o sak sak.o` and, built dynamic, cannot find
# the musl loader on the glibc build host. Paired with --disable-shared so there
# are no `gcc -shared` stublib links for -static to conflict with.
autodetect_compiler_CC="x86_64-linux-musl-gcc"
autodetect_compiler_CXX="x86_64-linux-musl-g++"
autodetect_compiler_CFLAGS="-Wno-format -Os -static"
autodetect_compiler_CXXFLAGS="-Wno-format -Os -static"
# ASPP (assembler-with-preprocessor) is the C compiler for a GCC toolchain;
# AS is the plain assembler. Both x86_64, libc-agnostic. ASPP is not in the
# launcher's fixed variable list, so only export_binding reaches it (a plain
# ASPP= assignment is a silent no-op that falls back to configure's
# ASPP="$CC -c" default; the same value here, but by luck, not mechanism).
autodetect_compiler_AS="x86_64-linux-musl-as"
autodetect_compiler_ASFLAGS=""
export_binding ASPP "x86_64-linux-musl-gcc -c"
# OCaml links executables through $CC; LD/DIRECT_LD are the plain linker used
# for partial links. PARTIALLD (ld -r) is set by the build command's env.
autodetect_compiler_LD="x86_64-linux-musl-ld"
autodetect_compiler_LDFLAGS=""
autodetect_compiler_LDLIBS=""
autodetect_compiler_DIRECT_LD="x86_64-linux-musl-ld"
