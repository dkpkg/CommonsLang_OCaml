# CommonsLang_OCaml

`CommonsLang_OCaml` packages OCaml compiler toolchains and related developer
tools for dk workspaces.

The planned package targets in this repository are:

- `CommonsLang_OCaml.OCaml.Bundle@5.4.1`
- `CommonsLang_OCaml.Toolchain.W64devkit@5.4.1`
- `CommonsLang_OCaml.Toolchain.LLVM_MinGW@5.4.1`
- `CommonsLang_OCaml.Base@4.14.3`
- `CommonsLang_OCaml.Base@5.5.0-beta1`
- `CommonsLang_OCaml.DkML@4.14.3003`
- `CommonsLang_OCaml.DkMLStatic@4.14.3003`
- `CommonsLang_OCaml.Opam@2.5.4`
- `CommonsLang_OCaml.Dune@3.23.4`

This repository is being ported from the legacy package definitions copied
into `etc\dk\v`.

The current `CommonsLang_OCaml.DkML` work is split into
`CommonsLang_OCaml.DkML.Bundle@4.14.3002`,
`CommonsLang_OCaml.DkML.RuntimeCommon.Bundle@2.4.2-18`, and
`CommonsLang_OCaml.DkML@4.14.3003`. The split keeps the compiler and runtime
archives separate while the compiler package stages `dkml-compiler@2.4.2-37`,
`dkml-runtime-common@2.4.2-18`, the `dra27/ocaml` 4.14.3 base commit plus the
relocatable backport patch series, and flexdll 0.43 and runs the upstream
setup/build scripts directly without invoking opam.

The first implemented `CommonsLang_OCaml.DkML@4.14.3003` surface is a
Windows_x86_64 host build.

`CommonsLang_OCaml.DkML` is the OCaml 4.14 toolchain for general builds, with
dynamic loading through FlexDLL and the DLL C runtime on Windows.

`CommonsLang_OCaml.DkMLStatic` is the OCaml 4.14 toolchain for native static
executables, linked on Windows against the static C runtime with no dynamic
loading. dk0, dk1 and mlfront-signify build with DkMLStatic.

`CommonsLang_OCaml.DkML@4.14.3002` is a copy of `DkML@4.14.3003`, so that locks and
generated drivers solved before 4.14.3003 still resolve.

Local validation of the toolchain packages also expects sibling checkouts of
`CommonsBase_GNU` and `CommonsBase_Std` so the test comments can import their
definitions directly.

Reusable local helper files now come from `dk.u` workspace assets rather than a
checked-in `Lookup.values.jsonc` bundle.
