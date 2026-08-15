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
# --post-transform (-k HOSTABISCRIPT) script for the Release.Linux_x86 DkML
# slot. r-c-ocaml-1-setup requires the -k script to be SELF-CONTAINED, because
# it installs ONLY this file into the reproducible build tree
# (share/dkml/repro/100co/...); it cannot source
# standard-compiler-env-to-ocaml-configure-env.sh (that file is not packaged
# there, so sourcing it fails at r-c-ocaml-2-build_host time). This ABI only
# ever uses the host multilib GCC through the slot's own i686-none-linux-gnu-*
# dispatch wrappers -- a plain GCC-family compiler -- so the standard script's
# MSVC/Xcode/Android/CMake autodetection is irrelevant and the few GCC-family
# adjustments it makes are inlined here.
#
# On entry autodetect_compiler() has populated autodetect_compiler_* and the
# helper `export_binding NAME VALUE` (adds NAME=VALUE to the launcher env).
# DKML_X86_BINDIR is the absolute bin/ of this slot, passed by the DkML.Unix
# Linux_x86 build commands.
#
# The standard script would set CC="gcc -m32" (it folds -m32 out of CFLAGS into
# CC). That two-word c_compiler is what dune later splits apart and loses; see
# x86-tool-wrapper.sh. Naming a single-word driver here is the whole point of
# this file.
set -euf

if [ -z "${DKML_X86_BINDIR:-}" ]; then
    echo "FATAL: DKML_X86_BINDIR is not set for the x86 post-transform" >&2
    exit 107
fi

# Put the slot's dispatch wrappers on PATH for configure/make (and for the
# baked bare tool names to resolve during this build). Consumers of the built
# compiler resolve the same bare names through the slot's
# bin/i686-none-linux-gnu-* wrappers, so ocamlc -config stays relocatable.
# NOTE: this binding alone does not reach OCaml's ./configure -- the DkML.Unix
# Linux_x86 build command runs r-c-ocaml-2-build_host through
# run-x86-build-host.sh, which puts the wrappers where autoconf will find them.
export_binding PATH "$DKML_X86_BINDIR:$PATH"

# Bare, single-word GCC-family drivers. Each wrapper supplies its own 32-bit
# flag (-m32 / --32 / -melf_i386), so no arch flag belongs in the *FLAGS below:
# a flag there would be dropped by any consumer that overrides dune's
# `:standard` C flags, which is exactly the defect these wrappers close.
# -Wno-format matches the standard script's GCC handling.
autodetect_compiler_CC="i686-none-linux-gnu-gcc"
autodetect_compiler_CXX="i686-none-linux-gnu-g++"
autodetect_compiler_CFLAGS="-Wno-format"
autodetect_compiler_CXXFLAGS="-Wno-format"
# ASPP (assembler-with-preprocessor) is the C compiler for a GCC toolchain; AS
# is the plain assembler.
autodetect_compiler_AS="i686-none-linux-gnu-as"
autodetect_compiler_ASFLAGS=""
ASPP="i686-none-linux-gnu-gcc -c"
# OCaml links executables through $CC; LD/DIRECT_LD are the plain linker used
# for partial links. PARTIALLD (ld -r) is set by the build command's env.
autodetect_compiler_LD="i686-none-linux-gnu-ld"
autodetect_compiler_LDFLAGS=""
autodetect_compiler_LDLIBS=""
autodetect_compiler_DIRECT_LD="i686-none-linux-gnu-ld"
