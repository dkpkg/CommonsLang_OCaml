# adopt-hello test

This directory holds a minimal opam+dune project that the
`test-quickstart-ocaml-adopt` workflow adopts end to end.

The package `dktest` ships one executable, `src/main.ml`, and declares no
dependencies beyond the recipe's base toolchain (the OCaml compiler and dune).
The workflow scaffolds a fresh `dk0 quickstart ocaml` project, copies these
files into it, and runs `CommonsLang_OCaml.Dk.OpamLock.Adopt`. Adopt solves the
lock, generates the source, driver, and final forms, and registers the
workspace assets. The workflow then builds and runs the executable, which prints
one line and exits.

The files:

| File | Role |
|---|---|
| `dune-project` | names the package and sets the dune language version |
| `dktest.opam` | the opam package metadata Adopt solves and locks |
| `src/dune` | the executable stanza whose `public_name` names the binary |
| `src/main.ml` | the executable body |
