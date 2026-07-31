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
# Musl variant of standard-compiler-env-to-ocaml-configure-env.sh used by the
# Release.Linux_x86_64_musl DkML slot: force the pinned x86_64-linux-musl
# cross toolchain, then delegate to the standard post-transform.
#
# DKML_MUSL_BINDIR is the absolute bin directory of the extracted
# x86_64-linux-musl-cross toolchain; the DkML.Unix musl slot commands pass it
# to both the setup and build_host invocations.
#
# The compiler variables enter the standard script as ABSOLUTE paths because
# its Mitigation GCC_EXE runs `realpath` on CC under `set -euf` (a bare name
# that is not a file aborts the transform). After the standard transforms they
# reduce to bare PATH-resolved names so the baked `ocamlc -config` stays
# relocatable, and the launcher gets DKML_MUSL_BINDIR on PATH so configure and
# make can resolve those bare names during the build itself. Consumers resolve
# them through the bin/x86_64-linux-musl-* dispatch wrappers shipped in the
# same slot.
set -euf

if [ -z "${DKML_MUSL_BINDIR:-}" ]; then
  echo "FATAL: DKML_MUSL_BINDIR is not set for the musl post-transform" >&2
  exit 107
fi

autodetect_compiler_CC="$DKML_MUSL_BINDIR/x86_64-linux-musl-gcc"
autodetect_compiler_CXX="$DKML_MUSL_BINDIR/x86_64-linux-musl-g++"
autodetect_compiler_AS="$DKML_MUSL_BINDIR/x86_64-linux-musl-as"
autodetect_compiler_LD="$DKML_MUSL_BINDIR/x86_64-linux-musl-ld"

# shellcheck disable=SC1091
. "$DKMLDIR/vendor/dkml-compiler/env/standard-compiler-env-to-ocaml-configure-env.sh"

# PATH for the configure/make launcher; bare names for the baked config so
# ocamlc -config stays relocatable (consumers resolve them through the slot's
# bin/x86_64-linux-musl-* dispatch wrappers on PATH). These are exactly the
# variable names autodetect_compiler_write_output emits into the launcher:
# CC/CXX/AS/LD and autodetect_compiler_DIRECT_LD. OCaml's configure derives
# ASPP from AS/CC, so it is not set here (the launcher does not carry ASPP).
export_binding PATH "$DKML_MUSL_BINDIR:$PATH"
autodetect_compiler_CC="x86_64-linux-musl-gcc"
autodetect_compiler_CXX="x86_64-linux-musl-g++"
autodetect_compiler_AS="x86_64-linux-musl-as"
autodetect_compiler_LD="x86_64-linux-musl-ld"
autodetect_compiler_DIRECT_LD="x86_64-linux-musl-ld"
