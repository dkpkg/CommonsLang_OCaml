# assets/opam-lock — the OCaml opam-lock helper

`dk_opam_lock.ml` is the heavy logic of `CommonsLang_OCaml.Dk.OpamLock.Solve`,
ported out of lua-ml (Lua 2.5) into OCaml. The dk0 `Solve` uirule stays thin:
it materializes `opam` and the `CommonsLang_OCaml.DkML@4.14.3` toolchain,
`get-asset`s the two `.ml` files here, compiles them with the materialized
`ocamlc`, runs the bytecode with `ocamlrun`, and `writefile`s the program's
stdout as the lock — mirroring `CommonsLang_Python`'s
`assets/uv-lock/dk_uv_lock.py`.

## Files

- `dk_opam_lock.ml` — hand-written helper (this is the source of truth).
- `opam_file_format.ml` — a **generated** single-file amalgam of
  [opam-file-format](https://github.com/ocaml/opam-file-format) 2.2.0. Do not
  edit by hand; regenerate with `tools/update-opam-file-format.ps1`. Used to
  cross-check (validate) the dependency-field scan and warn on any divergence.

## Build & run (what the Solve rule does)

    ocamlc -w -a unix.cma opam_file_format.ml dk_opam_lock.ml -o dk_opam_lock.bc
    ocamlrun dk_opam_lock.bc solve \
      --opam <opam> --work-dir <sandbox> --pins-file <dk-opam-pins.txt> \
      --root DkZero_Exec --root DkOne_Exec \
      [--slot Release.Windows_x86_64 ...] [--local-opam-dir <dir>] \
      [--switch <name>] [--wtest] [--msys2 <dir> --git <dir>] \
      [--repo-commit <c>] [--tool <id>]

`ocamlc`/`ocamlrun` come from the materialized DkML tree; `OCAMLLIB` must point
at its `lib/ocaml` (the Solve rule sets this in the capture env). Compilation
emits warnings from the generated amalgam, which is why the rule builds with
`-w -a`.

Contract: **stdout carries only the lock JSON** (the rule writes it verbatim);
all progress, `+ <command>` traces and warnings go to stderr. Exit 0 on
success, 1 on any fatal error (last stderr line = the reason).

## Self-test

    ocamlrun dk_opam_lock.bc selftest

Hermetic (no opam, no network): checks the SHA-256 implementation against FIPS
vectors, the JSON encoder byte-shape (sorted keys, 2-space indent, `[]` for
empty, `"local":"t"`, CRLF escaping), the opam-field scanners, and the pin-file
parser.

## Parity

The emitted lock is byte-identical to the lua rule's output. Preserved exactly:
the opam-field scanners (`top_level_quoted`/`checksums`/`unquote`), the
`opam show --field=` column de-indent, the JSON encoder, the discovery order of
`depends`, and the `"local":"t"` marker (lua-ml `x ~= nil` yields the *string*
`"t"`). The amalgam runs only as a validator of the dependency scan and never
changes the emitted bytes; flip it to primary only as a deliberate, separately
gated change.

Improvements over the lua rule that do not affect parity: `opam show` runs in
larger, concurrent batches; per-package source-size/`sha256` probes are
concurrent; and the source `sha256` fallback (for md5/sha512-only packages) is
computed with a pure-OCaml SHA-256 on every platform, not just Windows/certutil.

## Regenerating the amalgam

Rarely needed (the opam file format is stable). Requires an opam switch with
`ocamllex` and `menhir` (`opam install menhir`; DkML's `ocamlyacc` cannot build
the menhir grammar). Run:

    pwsh tools/update-opam-file-format.ps1 [-Version 2.2.0] [-OpamSwitch <sw>]

then update the `OpamFileFormat` asset `byteSize`/`sha256` in `dk.u` from the
checked-in LF bytes.
