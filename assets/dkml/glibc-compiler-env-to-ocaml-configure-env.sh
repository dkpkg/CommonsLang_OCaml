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
# --post-transform (-k HOSTABISCRIPT) script for the Release.Linux_x86_64
# (glibc) DkML slot. r-c-ocaml-1-setup requires the -k script to be
# SELF-CONTAINED, because it installs ONLY this file into the reproducible
# build tree (share/dkml/repro/100co/...); it cannot source
# standard-compiler-env-to-ocaml-configure-env.sh (that file is not packaged
# there, so sourcing it fails at r-c-ocaml-2-build_host time). This ABI only
# ever uses a PATH-resolved GCC-family host toolchain, so the standard
# script's MSVC/Xcode/Android/CMake autodetection is irrelevant.
#
# On entry autodetect_compiler() has populated autodetect_compiler_* and the
# helper `export_binding NAME VALUE` (adds NAME=VALUE to the launcher env).
#
# Issue #2 (github.com/dkpkg/CommonsLang_OCaml): autodetect_compiler_system()
# records absolute `command -v` paths, so the manylinux release build bakes
# /opt/rh/gcc-toolset-14/root/usr/bin/{gcc,as} into ocamlopt -config and no
# host without that RedHat toolset can compile native OCaml. Bare
# PATH-resolved names keep the config relocatable: on the manylinux release
# container they still resolve to gcc-toolset-14 (first on PATH), so shipped
# binaries keep the glibc 2.28 floor, while consumer hosts (Ubuntu 24.04,
# Debian, ...) resolve their own toolchain (e.g. apt build-essential).
# Single-word names because dune reads c_compiler as program+arguments and
# drops the arguments under :standard-overriding stanzas; see
# x86-compiler-env-to-ocaml-configure-env.sh.
#
# Issue #3 is NOT fixed here: gcc-toolset gcc is not --enable-default-pie, so
# a stock build's default libasmrun.a carries R_X86_64_32S relocations (in
# amd64.o and the runtime C objects) and native links fail on PIE-default
# hosts (Ubuntu 24.04, Debian 12+). The r-c-ocaml relocatable build clears
# CFLAGS before `make`, so a CFLAGS/ASPP -fPIC set here reaches only the
# installed ocamlc_cflags (user C stubs), never the default runtime objects.
# The runtime is made PIC by OCaml 4.14's own `./configure --with-pic`
# (threaded through DKML_HOST_OCAML_CONFIGURE in the Linux_x86_64 slot),
# which adds -fPIC to internal_cflags (the runtime .c objects) and to
# default_aspp (amd64.S). CFLAGS=-fPIC below is belt-and-braces so DkML also
# compiles user C stubs PIC on the non-PIE-default builder.
set -euf

# Bare, single-word GCC-family host tools (issue #2). No PATH binding and no
# DKML_*_BINDIR guard: bare gcc/as resolve in every context of this slot's
# build because the release container has gcc-toolset first on PATH.
autodetect_compiler_CC="gcc"
autodetect_compiler_CXX="g++"
autodetect_compiler_CFLAGS="-fPIC"
autodetect_compiler_CXXFLAGS="-fPIC"
# ASPP (assembler-with-preprocessor) and AS (plain assembler). ASPP is left to
# OCaml's configure: with --with-pic it becomes "$default_aspp -fPIC", which
# is what carries -fPIC into amd64.S. Setting ASPP here would not reach the
# runtime make anyway (the relocatable build clears the launcher's compiler
# env before `make`).
autodetect_compiler_AS="as"
autodetect_compiler_ASFLAGS=""
# OCaml links executables through $CC; LD/DIRECT_LD are the plain linker used
# for partial links. PARTIALLD (ld -r) is set by the build command's env.
# The stock autodetection's LDFLAGS=-melf_x86_64 and its absolute .ld64.sh
# LD wrapper are deliberately dropped: nothing from LD/LDFLAGS lands in
# ocamlopt -config for 4.14. If an ocamlmklib mixed-arch regression appears,
# restore autodetect_compiler_LDFLAGS="-melf_x86_64".
autodetect_compiler_LD="ld"
autodetect_compiler_LDFLAGS=""
autodetect_compiler_LDLIBS=""
autodetect_compiler_DIRECT_LD="ld"
