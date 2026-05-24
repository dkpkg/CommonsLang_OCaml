# CommonsLang_OCaml

`CommonsLang_OCaml` packages OCaml compiler toolchains and related developer
tools for dk workspaces.

The planned package targets in this repository are:

- `CommonsLang_OCaml.Lookup@1.0.0`
- `CommonsLang_OCaml.OCaml.Bundle@5.4.1`
- `CommonsLang_OCaml.Toolchain.W64devkit@5.4.1`
- `CommonsLang_OCaml.Toolchain.LLVM_MinGW@5.4.1`
- `CommonsLang_OCaml.Base@4.14.3`
- `CommonsLang_OCaml.Base@5.5.0-beta1`
- `CommonsLang_OCaml.DkML@4.14.3`
- `CommonsLang_OCaml.Opam@2.5.1`
- `CommonsLang_OCaml.Dune@3.23.1`

This repository is being ported from the legacy package definitions copied
into `etc\dk\v`.

The initial `CommonsLang_OCaml.DkML@4.14.3` wiring consumes the
`dkml-compiler` prerelease source archive and keeps the DkML package line
independent from the Base compiler line.

Local validation of the toolchain packages also expects sibling checkouts of
`CommonsBase_GNU` and `CommonsBase_Std` so the test comments can import their
definitions directly.
