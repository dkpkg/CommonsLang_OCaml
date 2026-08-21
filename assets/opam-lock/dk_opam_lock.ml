(* dk_opam_lock.ml -- the heavy logic of CommonsLang_OCaml.Dk.OpamLock.Solve,
   ported out of lua-ml into OCaml. Run at Solve time by the DkML toolchain the
   rule materializes (ocamlc + ocamlrun), mirroring CommonsLang_Python's
   assets/uv-lock/dk_uv_lock.py: the dk0 uirule stays thin (materialize opam +
   DkML, capture this program, writefile its stdout); all opam-field parsing,
   dependency reshaping, source probing and JSON encoding live here where they
   are testable and free of the lua-ml (Lua 2.5) footguns the rule documented.

   Compile (both units, in order) with the materialized DkML compiler:
     ocamlc -w -a unix.cma opam_file_format.ml dk_opam_lock.ml -o dk_opam_lock.bc
   Run:
     ocamlrun dk_opam_lock.bc solve --opam <opam> --work-dir <dir> \
       --pins-file <pins> [--pins-name <name>] --root <pkg> [--slot <slot> ...] [...]
     ocamlrun dk_opam_lock.bc selftest

   stdout carries ONLY the lock JSON (the rule writefiles it verbatim); every
   diagnostic, "+ <cmd>" trace and warning goes to stderr. Exit 0 on success,
   1 on any fatal error (the last stderr line is the reason).

   Byte-parity: the emitted lock is byte-identical to the lua rule's output.
   The opam-field scanners (top_level_quoted/checksums/unquote), the column
   de-indent in opam_show, the JSON encoder (sorted keys, 2-space indent, "[]"
   for empty, control-byte escaping, no newline translation), the discovery
   order of `depends`, and the `"local":"t"` marker (lua-ml `~= nil` yields the
   STRING "t") are all reproduced exactly. The vendored opam-file-format amalgam
   runs as an independent VALIDATOR of the dependency scan and logs any
   disagreement to stderr, without changing the emitted bytes. *)

let win = Sys.win32

(* --------------------------------------------------------------------- *)
(* String helpers -- faithful ports of the lua-ml module's scanners.     *)
(* --------------------------------------------------------------------- *)
module S = struct
  let is_white c = c = ' ' || c = '\t' || c = '\r' || c = '\n'

  let trim s =
    let n = String.length s in
    let a = ref 0 in
    while !a < n && is_white s.[!a] do incr a done;
    if !a >= n then ""
    else begin
      let b = ref (n - 1) in
      while !b >= 0 && is_white s.[!b] do decr b done;
      String.sub s !a (!b - !a + 1)
    end

  let unquote s =
    let s = trim s in
    let n = String.length s in
    if n >= 2 && s.[0] = '"' && s.[n - 1] = '"' then String.sub s 1 (n - 2) else s

  (* Non-empty trimmed lines, splitting on '\n' only. *)
  let lines s =
    let out = ref [] in
    let n = String.length s in
    let i = ref 0 in
    while !i < n do
      let j = try String.index_from s !i '\n' with Not_found -> n in
      let line = String.sub s !i (j - !i) in
      let t = trim line in
      if t <> "" then out := t :: !out;
      i := if j < n then j + 1 else n
    done;
    List.rev !out

  (* Whitespace-split tokens (no quoting/escapes), matching lua words(). *)
  let words s =
    let out = ref [] in
    let n = String.length s in
    let i = ref 0 in
    while !i < n do
      while !i < n && is_white s.[!i] do incr i done;
      if !i < n then begin
        let j = ref !i in
        while !j < n && not (is_white s.[!j]) do incr j done;
        out := String.sub s !i (!j - !i) :: !out;
        i := !j
      end
    done;
    List.rev !out

  (* Index of the FIRST '.' (opam names have no dots), or None. *)
  let first_dot s =
    match String.index_opt s '.' with Some i -> Some i | None -> None

  let lower = String.lowercase_ascii

  let starts_with ~prefix s =
    let lp = String.length prefix in
    String.length s >= lp && String.sub s 0 lp = prefix

  let ends_with ~suffix s =
    let ls = String.length suffix and n = String.length s in
    n >= ls && String.sub s (n - ls) ls = suffix

  let contains_sub ~needle hay =
    let nn = String.length needle and nh = String.length hay in
    if nn = 0 then true
    else begin
      let rec go i = i + nn <= nh && (String.sub hay i nn = needle || go (i + 1)) in
      go 0
    end
end

(* --------------------------------------------------------------------- *)
(* opam field scanners (byte-identical to the lua-ml originals).          *)
(* --------------------------------------------------------------------- *)

(* Top-level (brace-depth 0) quoted tokens: the package names in a `depends:`
   style field. Quoted tokens inside {filters} are constraints, not names.
   Parens do NOT change depth (only {} do), so disjunction members count. *)
let top_level_quoted s =
  let names = ref [] in
  let n = String.length s in
  let i = ref 0 and depth = ref 0 in
  while !i < n do
    let c = s.[!i] in
    if c = '{' then (incr depth; incr i)
    else if c = '}' then (decr depth; incr i)
    else if c = '"' then begin
      let j = ref (!i + 1) in
      while !j < n && s.[!j] <> '"' do incr j done;
      if !depth = 0 then names := String.sub s (!i + 1) (!j - !i - 1) :: !names;
      i := !j + 1
    end else incr i
  done;
  List.rev !names

(* The same scan, pairing each depth-0 name with the {filter} that follows it
   ("" when it has none). Positions, not a name-keyed map: opam may name a
   package twice with different filters (ppxlib lists sexplib0 as a real
   dependency AND under with-test), and collapsing by name would let the
   test-only occurrence mask the real one. *)
let top_level_quoted_filtered s =
  let out = ref [] in
  let n = String.length s in
  let i = ref 0 and depth = ref 0 in
  (* Index in [out] of the name awaiting its filter, if the scan is still in
     the whitespace directly after it. *)
  let pending = ref None in
  while !i < n do
    let c = s.[!i] in
    if c = '{' then begin
      match !pending with
      | Some idx when !depth = 0 ->
          let j = ref (!i + 1) and d2 = ref 1 in
          while !j < n && !d2 > 0 do
            (if s.[!j] = '{' then incr d2 else if s.[!j] = '}' then decr d2);
            if !d2 > 0 then incr j
          done;
          let filt = String.sub s (!i + 1) (!j - !i - 1) in
          out := List.mapi (fun k (nm, f) -> if k = idx then (nm, filt) else (nm, f)) !out;
          pending := None;
          i := !j + 1
      | _ -> incr depth; incr i
    end
    else if c = '}' then (decr depth; incr i)
    else if c = '"' then begin
      let j = ref (!i + 1) in
      while !j < n && s.[!j] <> '"' do incr j done;
      if !depth = 0 then begin
        out := !out @ [ (String.sub s (!i + 1) (!j - !i - 1), "") ];
        pending := Some (List.length !out - 1)
      end;
      i := !j + 1
    end
    else begin
      (if c <> ' ' && c <> '\t' && c <> '\n' && c <> '\r' then pending := None);
      incr i
    end
  done;
  !out

(* Is this dependency needed only to TEST or DOCUMENT its package? opam gates
   such an edge behind with-test, with-doc or with-dev-setup, all false for the
   builds this lock drives. Recording one as a build edge makes the graph
   CYCLIC -- re depends on ppx_expect only to run its tests while ppx_expect
   really depends on re -- and no build order satisfies a cycle. An alternation
   ("|") may still hold when the gate variable is false, so it stays required. *)
let is_test_only_filter f =
  let has sub =
    let n = String.length f and m = String.length sub in
    let rec go i = i + m <= n && (String.sub f i m = sub || go (i + 1)) in
    m > 0 && go 0
  in
  f <> "" && (not (String.contains f '|'))
  && (has "with-test" || has "with-doc" || has "with-dev-setup")

(* Checksums ("<algo>=<hex>") from a url.checksum: field: any quoted token
   containing '='; else the whole field unquoted if it contains '='. *)
let checksums s =
  let toks = top_level_quoted s in
  let out = List.filter (fun v -> String.contains v '=') toks in
  if out <> [] then out
  else
    let u = S.unquote s in
    if String.contains u '=' then [ u ] else []

(* --------------------------------------------------------------------- *)
(* Amalgam validator: parse a depends/depopts field with opam-file-format *)
(* and report the depth-0 string atoms. Used only to cross-check the byte *)
(* scanner and warn on divergence; never feeds the emitted lock.          *)
(* --------------------------------------------------------------------- *)
module Validator = struct
  module FP = Opam_file_format.OpamParserTypes.FullPos

  (* Collect string atoms that are NOT inside an Option's {filter}: the AST
     analogue of top_level_quoted's brace-depth-0 rule. *)
  let rec atoms acc (v : FP.value) =
    match v.FP.pelem with
    | FP.String s -> s :: acc
    | FP.Option (base, _filters) -> atoms acc base
    | FP.List l -> List.fold_left atoms acc l.FP.pelem
    | FP.Group g -> List.fold_left atoms acc g.FP.pelem
    | FP.Logop (_, a, b) -> atoms (atoms acc a) b
    | FP.Pfxop (_, a) -> atoms acc a
    | FP.Prefix_relop (_, a) -> atoms acc a
    | FP.Relop (_, a, b) -> atoms (atoms acc a) b
    | FP.Env_binding (a, _, b) -> atoms (atoms acc a) b
    | FP.Bool _ | FP.Int _ | FP.Ident _ -> acc

  (* Returns the string-atom list (source order) or None if the field could
     not be parsed. The field text has no surrounding brackets, so wrap it. *)
  let names field =
    if S.trim field = "" then Some []
    else
      match
        Opam_file_format.OpamParser.FullPos.value_from_string
          ("[\n" ^ field ^ "\n]") "field"
      with
      | v -> Some (List.rev (atoms [] v))
      | exception _ -> None

  let sorted l = List.sort String.compare l

  (* Warn (stderr) when the amalgam and the byte scanner disagree as SETS. *)
  let check ~pkg ~field ~scanner text =
    match names text with
    | None ->
      Printf.eprintf
        "[opam-lock] WARN: amalgam could not parse %s field of %s\n" field pkg
    | Some got ->
      if sorted got <> sorted scanner then
        Printf.eprintf
          "[opam-lock] WARN: amalgam/scanner disagree on %s of %s: amalgam=[%s] scanner=[%s]\n"
          field pkg (String.concat "," got) (String.concat "," scanner)
end

(* --------------------------------------------------------------------- *)
(* JSON encoder -- byte-identical to the lua-ml json_encode.             *)
(* --------------------------------------------------------------------- *)
module Json = struct
  type t =
    | Null
    | Int of int
    | Str of string
    | Arr of t list
    | Obj of (string * t) list

  (* Escape as lua json_str: quote, backslash, newline, CR and TAB get
     backslash escapes; other control bytes become a space; everything else
     (including UTF-8 high bytes) passes through verbatim. *)
  let escape b s =
    Buffer.add_char b '"';
    String.iter
      (fun c ->
        match c with
        | '"' -> Buffer.add_string b "\\\""
        | '\\' -> Buffer.add_string b "\\\\"
        | '\n' -> Buffer.add_string b "\\n"
        | '\r' -> Buffer.add_string b "\\r"
        | '\t' -> Buffer.add_string b "\\t"
        | c when Char.code c < 32 -> Buffer.add_char b ' '
        | c -> Buffer.add_char b c)
      s;
    Buffer.add_char b '"'

  let rec enc b indent v =
    let child = indent ^ "  " in
    match v with
    | Null -> Buffer.add_string b "null"
    | Int n -> Buffer.add_string b (string_of_int n)
    | Str s -> escape b s
    | Arr [] -> Buffer.add_string b "[]"
    | Obj [] -> Buffer.add_string b "[]" (* lua: empty table -> "[]" *)
    | Arr items ->
      Buffer.add_string b "[\n";
      List.iteri
        (fun i x ->
          if i > 0 then Buffer.add_string b ",\n";
          Buffer.add_string b child;
          enc b child x)
        items;
      Buffer.add_char b '\n';
      Buffer.add_string b indent;
      Buffer.add_char b ']'
    | Obj fields ->
      let fields = List.sort (fun (a, _) (c, _) -> String.compare a c) fields in
      Buffer.add_string b "{\n";
      List.iteri
        (fun i (k, x) ->
          if i > 0 then Buffer.add_string b ",\n";
          Buffer.add_string b child;
          escape b k;
          Buffer.add_string b ": ";
          enc b child x)
        fields;
      Buffer.add_char b '\n';
      Buffer.add_string b indent;
      Buffer.add_char b '}'

  let to_string v =
    let b = Buffer.create 65536 in
    enc b "" v;
    Buffer.contents b
end

(* --------------------------------------------------------------------- *)
(* SHA-256 (FIPS 180-4), pure OCaml -- makes the source-hash fallback     *)
(* work on every platform (the lua rule could only shell certutil on      *)
(* Windows). Same bytes -> same digest, so this never affects parity.     *)
(* --------------------------------------------------------------------- *)
module Sha256 = struct
  let k =
    [| 0x428a2f98l; 0x71374491l; 0xb5c0fbcfl; 0xe9b5dba5l; 0x3956c25bl;
       0x59f111f1l; 0x923f82a4l; 0xab1c5ed5l; 0xd807aa98l; 0x12835b01l;
       0x243185bel; 0x550c7dc3l; 0x72be5d74l; 0x80deb1fel; 0x9bdc06a7l;
       0xc19bf174l; 0xe49b69c1l; 0xefbe4786l; 0x0fc19dc6l; 0x240ca1ccl;
       0x2de92c6fl; 0x4a7484aal; 0x5cb0a9dcl; 0x76f988dal; 0x983e5152l;
       0xa831c66dl; 0xb00327c8l; 0xbf597fc7l; 0xc6e00bf3l; 0xd5a79147l;
       0x06ca6351l; 0x14292967l; 0x27b70a85l; 0x2e1b2138l; 0x4d2c6dfcl;
       0x53380d13l; 0x650a7354l; 0x766a0abbl; 0x81c2c92el; 0x92722c85l;
       0xa2bfe8a1l; 0xa81a664bl; 0xc24b8b70l; 0xc76c51a3l; 0xd192e819l;
       0xd6990624l; 0xf40e3585l; 0x106aa070l; 0x19a4c116l; 0x1e376c08l;
       0x2748774cl; 0x34b0bcb5l; 0x391c0cb3l; 0x4ed8aa4al; 0x5b9cca4fl;
       0x682e6ff3l; 0x748f82eel; 0x78a5636fl; 0x84c87814l; 0x8cc70208l;
       0x90befffal; 0xa4506cebl; 0xbef9a3f7l; 0xc67178f2l |]

  let ( &: ) = Int32.logand
  let ( ^: ) = Int32.logxor
  let ( +: ) = Int32.add
  let lnot32 = Int32.lognot

  let rotr x n =
    Int32.logor (Int32.shift_right_logical x n) (Int32.shift_left x (32 - n))

  let digest_bytes (msg : bytes) =
    let h = [| 0x6a09e667l; 0xbb67ae85l; 0x3c6ef372l; 0xa54ff53al;
               0x510e527fl; 0x9b05688cl; 0x1f83d9abl; 0x5be0cd19l |] in
    let len = Bytes.length msg in
    let bitlen = Int64.of_int (len * 8) in
    (* pad: 0x80, zeros, 64-bit big-endian length -> multiple of 64 *)
    let padlen =
      let r = (len + 1) mod 64 in
      if r <= 56 then 56 - r else 120 - r
    in
    let total = len + 1 + padlen + 8 in
    let m = Bytes.make total '\000' in
    Bytes.blit msg 0 m 0 len;
    Bytes.set m len '\x80';
    for i = 0 to 7 do
      Bytes.set m (total - 1 - i)
        (Char.chr (Int64.to_int (Int64.logand (Int64.shift_right_logical bitlen (8 * i)) 0xFFL)))
    done;
    let w = Array.make 64 0l in
    let nblocks = total / 64 in
    for blk = 0 to nblocks - 1 do
      let base = blk * 64 in
      for t = 0 to 15 do
        let o = base + (t * 4) in
        w.(t) <-
          Int32.logor
            (Int32.shift_left (Int32.of_int (Char.code (Bytes.get m o))) 24)
            (Int32.logor
               (Int32.shift_left (Int32.of_int (Char.code (Bytes.get m (o + 1)))) 16)
               (Int32.logor
                  (Int32.shift_left (Int32.of_int (Char.code (Bytes.get m (o + 2)))) 8)
                  (Int32.of_int (Char.code (Bytes.get m (o + 3))))))
      done;
      for t = 16 to 63 do
        let s0 = rotr w.(t - 15) 7 ^: rotr w.(t - 15) 18 ^: Int32.shift_right_logical w.(t - 15) 3 in
        let s1 = rotr w.(t - 2) 17 ^: rotr w.(t - 2) 19 ^: Int32.shift_right_logical w.(t - 2) 10 in
        w.(t) <- w.(t - 16) +: s0 +: w.(t - 7) +: s1
      done;
      let a = ref h.(0) and b = ref h.(1) and c = ref h.(2) and d = ref h.(3) in
      let e = ref h.(4) and f = ref h.(5) and g = ref h.(6) and hh = ref h.(7) in
      for t = 0 to 63 do
        let s1 = rotr !e 6 ^: rotr !e 11 ^: rotr !e 25 in
        let ch = (!e &: !f) ^: (lnot32 !e &: !g) in
        let t1 = !hh +: s1 +: ch +: k.(t) +: w.(t) in
        let s0 = rotr !a 2 ^: rotr !a 13 ^: rotr !a 22 in
        let maj = (!a &: !b) ^: (!a &: !c) ^: (!b &: !c) in
        let t2 = s0 +: maj in
        hh := !g; g := !f; f := !e; e := !d +: t1;
        d := !c; c := !b; b := !a; a := t1 +: t2
      done;
      h.(0) <- h.(0) +: !a; h.(1) <- h.(1) +: !b;
      h.(2) <- h.(2) +: !c; h.(3) <- h.(3) +: !d;
      h.(4) <- h.(4) +: !e; h.(5) <- h.(5) +: !f;
      h.(6) <- h.(6) +: !g; h.(7) <- h.(7) +: !hh
    done;
    let buf = Buffer.create 64 in
    Array.iter (fun x -> Buffer.add_string buf (Printf.sprintf "%08lx" (Int32.logand x 0xFFFFFFFFl))) h;
    Buffer.contents buf

  let digest_string s = digest_bytes (Bytes.of_string s)

  let digest_file path =
    let ic = open_in_bin path in
    let n = in_channel_length ic in
    let b = Bytes.create n in
    really_input ic b 0 n;
    close_in ic;
    digest_bytes b
end

(* --------------------------------------------------------------------- *)
(* Process capture. Each child writes stdout and stderr to its own temp   *)
(* files (never pipes): deadlock-free and trivially concurrent. run_many  *)
(* runs up to k children at once (independent opam show chunks and source *)
(* probes), which is where the wall-clock win over the lua rule comes.    *)
(* --------------------------------------------------------------------- *)
module Proc = struct
  type result = { code : int; stdout : string; stderr : string }

  let read_file path =
    let ic = open_in_bin path in
    let n = in_channel_length ic in
    let s = really_input_string ic n in
    close_in ic;
    s

  let devnull = if win then "NUL" else "/dev/null"

  (* Drop the OCaml compiler/runtime lib-locating variables the Solve rule sets
     so its materialized ocamlc/ocamlrun work: opam and curl must never inherit
     them (a stray OCAMLLIB could steer opam's sys-ocaml-* probes to the DkML
     stdlib and change a PATH-mode solve). The old lua rule ran opam directly
     without these set, so stripping them keeps the solve byte-identical. *)
  let stripped = [ "OCAMLLIB"; "CAMLLIB"; "CAML_LD_LIBRARY_PATH" ]

  let merge_env adds =
    let tbl = Hashtbl.create 64 in
    let order = ref [] in
    let put k v =
      if not (Hashtbl.mem tbl k) then order := k :: !order;
      Hashtbl.replace tbl k v
    in
    Array.iter
      (fun kv ->
        match String.index_opt kv '=' with
        | Some i ->
          let k = String.sub kv 0 i in
          if not (List.mem k stripped) then put k (String.sub kv (i + 1) (String.length kv - i - 1))
        | None -> if not (List.mem kv stripped) then put kv "")
      (Unix.environment ());
    List.iter (fun (k, v) -> put k v) adds;
    Array.of_list (List.rev_map (fun k -> k ^ "=" ^ Hashtbl.find tbl k) !order)

  let trace prog args =
    Printf.eprintf "+ %s %s\n%!" prog (String.concat " " args)

  (* Run up to k of the given commands concurrently; results in input order. *)
  let run_many ?(k = 8) (cmds : (string * string list * (string * string) list) array) =
    let n = Array.length cmds in
    let results = Array.make n { code = 255; stdout = ""; stderr = "" } in
    let launch idx =
      let prog, args, adds = cmds.(idx) in
      trace prog args;
      let outp = Filename.temp_file "dkol" ".out" in
      let errp = Filename.temp_file "dkol" ".err" in
      let infd = Unix.openfile devnull [ Unix.O_RDONLY ] 0 in
      let outfd = Unix.openfile outp [ Unix.O_WRONLY; Unix.O_TRUNC ] 0o600 in
      let errfd = Unix.openfile errp [ Unix.O_WRONLY; Unix.O_TRUNC ] 0o600 in
      let env = merge_env adds in
      let pid =
        try Unix.create_process_env prog (Array.of_list (prog :: args)) env infd outfd errfd
        with e ->
          Unix.close infd; Unix.close outfd; Unix.close errfd;
          (try Sys.remove outp with _ -> ());
          (try Sys.remove errp with _ -> ());
          raise e
      in
      Unix.close outfd; Unix.close errfd;
      (idx, pid, infd, outp, errp)
    in
    let reap (idx, pid, infd, outp, errp) =
      let _, status = Unix.waitpid [] pid in
      Unix.close infd;
      let code = match status with Unix.WEXITED c -> c | _ -> 255 in
      let stdout = try read_file outp with _ -> "" in
      let stderr = try read_file errp with _ -> "" in
      (try Sys.remove outp with _ -> ());
      (try Sys.remove errp with _ -> ());
      results.(idx) <- { code; stdout; stderr }
    in
    let i = ref 0 in
    while !i < n do
      let hi = min n (!i + k) in
      let batch = Array.init (hi - !i) (fun j -> launch (!i + j)) in
      Array.iter reap batch;
      i := hi
    done;
    results

  (* status is always "exit" here: we distinguish a spawn failure by an empty
     result. A single command. *)
  let run ?(adds = []) prog args =
    (run_many ~k:1 [| (prog, args, adds) |]).(0)

  let run_checked prog args =
    let r = run prog args in
    if r.code <> 0 then begin
      Printf.eprintf "[opam-lock] FATAL: %s exited %d\n%s\n" prog r.code r.stderr;
      exit 1
    end;
    r
end

(* --------------------------------------------------------------------- *)
(* Source-archive helpers (byte-identical semantics to the lua originals) *)
(* --------------------------------------------------------------------- *)

let curl_exe = if win then "C:\\Windows\\System32\\curl.exe" else "curl"

(* opam content-addressed cache URL; prefer sha512 > md5 > sha256. *)
let cache_url sums =
  let find pfx =
    let p = pfx ^ "=" in
    let rec go = function
      | [] -> ""
      | x :: _ when S.starts_with ~prefix:p x -> String.sub x (String.length p) (String.length x - String.length p)
      | _ :: t -> go t
    in
    go sums
  in
  let sha512 = find "sha512" and md5 = find "md5" and sha256 = find "sha256" in
  let kind, hex =
    if sha512 <> "" then ("sha512", sha512)
    else if md5 <> "" then ("md5", md5)
    else if sha256 <> "" then ("sha256", sha256)
    else ("", "")
  in
  if String.length hex < 2 then None
  else Some (Printf.sprintf "https://opam.ocaml.org/cache/%s/%s/%s" kind (String.sub hex 0 2) hex)

let archive_type url =
  if S.ends_with ~suffix:".tar.gz" url || S.ends_with ~suffix:".tgz" url then "tgz"
  else if S.ends_with ~suffix:".tar.xz" url || S.ends_with ~suffix:".txz" url then "txz"
  else if S.ends_with ~suffix:".tar.bz2" url || S.ends_with ~suffix:".tbz" url then "tbz"
  else if S.ends_with ~suffix:".tar" url then "tar"
  else "tgz"

let has_bundle_checksum sums =
  List.exists
    (fun v ->
      S.starts_with ~prefix:"sha256=" v || S.starts_with ~prefix:"sha1=" v
      || S.starts_with ~prefix:"blake2b256=" v)
    sums

(* Byte size via curl: HEAD (last content-length wins), then a real GET
   (%{size_download}) when HEAD gives 0/absent (CDN redirects). *)
let source_size url =
  let digits_of ln =
    (* first run of digits after "content-length:" *)
    let n = String.length ln in
    let b = Buffer.create 16 in
    let i = ref 15 and stop = ref false in
    while !i < n && not !stop do
      let c = ln.[!i] in
      if c >= '0' && c <= '9' then Buffer.add_char b c
      else if Buffer.length b > 0 then stop := true;
      incr i
    done;
    Buffer.contents b
  in
  let r = Proc.run curl_exe [ "-f"; "-sIL"; url ] in
  let size = ref None in
  if r.code = 0 then
    List.iter
      (fun ln ->
        if S.starts_with ~prefix:"content-length:" (S.lower ln) then begin
          let d = digits_of (S.lower ln) in
          if d <> "" then size := Some (int_of_string d)
        end)
      (S.lines r.stdout);
  (match !size with
   | Some s when s > 0 -> Some s
   | _ ->
     let g = Proc.run curl_exe [ "-f"; "-sL"; "-o"; Proc.devnull; "-w"; "%{size_download}"; url ] in
     if g.code = 0 then
       match int_of_string_opt (S.trim g.stdout) with
       | Some n when n > 0 -> Some n
       | _ -> None
     else None)

(* sha256 of the archive: download with curl, hash in OCaml (all platforms). *)
let source_sha256 ~workdir url =
  let tmp = Filename.concat workdir "dk-opamlock-src.download" in
  let dl = Proc.run curl_exe [ "-f"; "-sL"; "-o"; tmp; url ] in
  if dl.code <> 0 then None
  else
    match Sha256.digest_file tmp with
    | h -> (try Sys.remove tmp with _ -> ()); Some h
    | exception _ -> (try Sys.remove tmp with _ -> ()); None

(* --------------------------------------------------------------------- *)
(* opam show: batched + concurrent (bigger arg budget than the lua rule;  *)
(* helper spawns via CreateProcess so there is no cmd.exe 8 KB cap).      *)
(* Output shape and column de-indent are reproduced exactly.              *)
(* --------------------------------------------------------------------- *)

let show_fields = [ "url.src:"; "url.checksum:"; "depends:"; "build:"; "install:"; "depopts:" ]

(* Parse one `opam show` chunk into by_key : (name.version, (field,value) list). *)
let parse_show_chunk reqfields stdout by_key =
  let w = List.fold_left (fun acc f -> max acc (String.length f + 1)) 0 reqfields in
  let firstfield = List.hd reqfields in
  let in_fields tok = List.mem tok reqfields in
  let deindent line =
    let n = String.length line in
    if n > w then String.sub line w (n - w) else ""
  in
  (* raw lines: split on '\n' only, keep leading ws + trailing CR *)
  let raw = stdout in
  let n = String.length raw in
  let rl = ref [] in
  let i = ref 0 in
  while !i < n do
    let j = try String.index_from raw !i '\n' with Not_found -> n in
    rl := String.sub raw !i (j - !i) :: !rl;
    i := if j < n then j + 1 else n
  done;
  let rl = List.rev !rl in
  let cur = ref [] and curfield = ref None and buf = ref "" and have_cur = ref false in
  let store_field () =
    match !curfield with
    | Some f -> cur := (f, S.trim !buf) :: List.remove_assoc f !cur
    | None -> ()
  in
  let finalize () =
    if !have_cur then begin
      let nm = S.unquote (try List.assoc "name:" !cur with Not_found -> "") in
      let vr = S.unquote (try List.assoc "version:" !cur with Not_found -> "") in
      if nm <> "" && vr <> "" then Hashtbl.replace by_key (nm ^ "." ^ vr) !cur
    end
  in
  List.iter
    (fun line ->
      let ll = String.length line in
      let p = ref 0 in
      while !p < ll && not (S.is_white line.[!p]) do incr p done;
      let token = String.sub line 0 !p in
      if in_fields token then begin
        store_field ();
        if token = firstfield then begin
          finalize ();
          cur := []; have_cur := true
        end;
        curfield := Some token;
        buf := deindent line
      end
      else if !curfield <> None then buf := !buf ^ "\n" ^ deindent line)
    rl;
  store_field ();
  finalize ()

(* Batch all keys into few `opam show` calls (never same name twice per chunk),
   run the chunks concurrently, and merge. Returns key -> (field,value) list. *)
let opam_show_all ~opam ~switchargs ~keys =
  let reqfields = "name:" :: "version:" :: show_fields in
  let maxkeys = 30000 in
  (* build chunks *)
  let chunks = ref [] and chunk = ref [] and names = ref [] and clen = ref 0 in
  let flush () = if !chunk <> [] then (chunks := List.rev !chunk :: !chunks; chunk := []; names := []; clen := 0) in
  List.iter
    (fun key ->
      let nm = match S.first_dot key with Some d -> String.sub key 0 d | None -> key in
      let klen = String.length key + 1 in
      if !chunk <> [] && (!clen + klen > maxkeys || List.mem nm !names) then flush ();
      chunk := key :: !chunk; names := nm :: !names; clen := !clen + klen)
    keys;
  flush ();
  let chunks = List.rev !chunks in
  let cmds =
    Array.of_list
      (List.map
         (fun ks ->
           let args = ("show" :: ("--field=" ^ String.concat "," reqfields) :: switchargs) @ ks in
           (opam, args, []))
         chunks)
  in
  let results = Proc.run_many cmds in
  let by_key : (string, (string * string) list) Hashtbl.t = Hashtbl.create 256 in
  Array.iter (fun (r : Proc.result) -> parse_show_chunk reqfields r.stdout by_key) results;
  by_key

(* --------------------------------------------------------------------- *)
(* Pin table (dk-opam-pins.txt).                                          *)
(* --------------------------------------------------------------------- *)
type pins = {
  repos : (string * string) list;  (* name, url -- in file order *)
  reponames : string list;
  pinned : (string * string) list; (* name, version *)
  floats : string list;
  archexcludes : (string * string) list; (* name, arch *)
}

let parse_pins content =
  let repos = ref [] and reponames = ref [] and pinned = ref []
  and floats = ref [] and arche = ref [] in
  List.iter
    (fun line ->
      if not (S.starts_with ~prefix:"#" line) then
        match S.words line with
        | "repo" :: name :: url :: _ -> repos := (name, url) :: !repos; reponames := name :: !reponames
        | "pin" :: name :: ver :: _ -> pinned := (name, ver) :: !pinned
        | "float" :: name :: _ -> floats := name :: !floats
        | "archexclude" :: name :: arch :: _ -> arche := (name, arch) :: !arche
        | _ -> ())
    (S.lines content);
  { repos = List.rev !repos; reponames = List.rev !reponames;
    pinned = List.rev !pinned; floats = List.rev !floats;
    archexcludes = List.rev !arche }

(* --------------------------------------------------------------------- *)
(* Switch setup: generate the constraints repo + opamrc, init/add/create. *)
(* --------------------------------------------------------------------- *)

let write_file path content =
  let dir = Filename.dirname path in
  (* mkdir -p *)
  let rec mkp d =
    if d <> "" && d <> "." && d <> "/" && not (Sys.file_exists d) then begin
      mkp (Filename.dirname d);
      (try Unix.mkdir d 0o755 with Unix.Unix_error (Unix.EEXIST, _, _) -> ())
    end
  in
  mkp dir;
  let oc = open_out_bin path in
  output_string oc content;
  close_out oc

let opamrc_body repos =
  let b = Buffer.create 1024 in
  let a = Buffer.add_string b in
  a "opam-version: \"2.0\"\n";
  a "# Generated by CommonsLang_OCaml.Dk.OpamLock for hermetic lock solving.\n";
  a "# Why each setting: this root only ever SOLVES dependencies (an empty\n";
  a "# switch with exact version pins); it never builds or installs packages.\n";
  a "\n";
  a "# All pinned repositories are seeded at init so the large upstream\n";
  a "# default repository is never fetched.\n";
  a "repositories: [\n";
  List.iter (fun (name, url) -> a (Printf.sprintf "  \"%s\" {\"%s\"}\n" name url)) repos;
  a "]\n";
  a "\n";
  a "# Nothing is built in this root, so no compiler switch is ever wanted\n";
  a "# and no default invariant should constrain switch creation.\n";
  a "default-compiler: []\n";
  a "default-invariant: []\n";
  a "\n";
  a "# Solve-only: no host tools (make, cc, curl, tar, unzip, bwrap) need to\n";
  a "# exist at init time, so a minimal container can run the solve.\n";
  a "required-tools: []\n";
  a "recommended-tools: []\n";
  a "\n";
  a "# Sandbox-free by construction: empty wrap commands mean no sandbox.sh\n";
  a "# is ever invoked (complements --disable-sandboxing on the init call).\n";
  a "wrap-build-commands: []\n";
  a "wrap-install-commands: []\n";
  a "wrap-remove-commands: []\n";
  a "\n";
  a "# Disable the host ocamlc probes. The opamrc grammar rejects an empty\n";
  a "# eval-variables list, but an empty command evaluates to nothing, which\n";
  a "# leaves each variable undefined: every host then looks like a host\n";
  a "# without an OCaml installation, so host state cannot leak into\n";
  a "# dependency filter evaluation and change the solve per machine.\n";
  a "eval-variables: [\n";
  a "  [sys-ocaml-version [] \"disabled for hermetic solving\"]\n";
  a "  [sys-ocaml-system [] \"disabled for hermetic solving\"]\n";
  a "  [sys-ocaml-arch [] \"disabled for hermetic solving\"]\n";
  a "  [sys-ocaml-cc [] \"disabled for hermetic solving\"]\n";
  a "  [sys-ocaml-libc [] \"disabled for hermetic solving\"]\n";
  a "]\n";
  Buffer.contents b

(* Returns (constraints_pkg option, archpkgs : (arch,pkgname) list, repos_decl). *)
let setup_switch ~opam ~switch ~workdir ~pins ~local_opam_dir ~winlocs ~fresh =
  let p = pins in
  (* constraints repo *)
  let constraints_pkg = ref None and archpkgs = ref [] and csrepo_url = ref None in
  if p.pinned <> [] then begin
    constraints_pkg := Some "dk-solve-constraints";
    let csrepo = Filename.concat workdir "csrepo" in
    write_file (Filename.concat csrepo "repo") "opam-version: \"2.0\"\n";
    csrepo_url := Some csrepo;
    let b = Buffer.create 4096 in
    Buffer.add_string b "opam-version: \"2.0\"\n";
    Buffer.add_string b "synopsis: \"Generated version lock for the dk opam solve\"\n";
    Buffer.add_string b "conflicts: [\n";
    List.iter (fun (name, ver) -> Buffer.add_string b (Printf.sprintf "  \"%s\" {!= \"%s\"}\n" name ver)) p.pinned;
    Buffer.add_string b "]\n";
    write_file (Filename.concat csrepo "packages/dk-solve-constraints/dk-solve-constraints.1/opam") (Buffer.contents b);
    (* per-arch exclusion packages *)
    let archmap = Hashtbl.create 8 and archorder = ref [] in
    List.iter
      (fun (name, arch) ->
        if not (Hashtbl.mem archmap arch) then (Hashtbl.add archmap arch (ref []); archorder := arch :: !archorder);
        let l = Hashtbl.find archmap arch in l := name :: !l)
      p.archexcludes;
    List.iter
      (fun arch ->
        let names = List.rev !(Hashtbl.find archmap arch) in
        let apkg = "dk-solve-arch-" ^ arch in
        let b = Buffer.create 512 in
        Buffer.add_string b "opam-version: \"2.0\"\n";
        Buffer.add_string b "synopsis: \"Generated arch exclusions for the dk opam solve\"\n";
        Buffer.add_string b "conflicts: [\n";
        List.iter (fun n -> Buffer.add_string b (Printf.sprintf "  \"%s\"\n" n)) names;
        Buffer.add_string b "]\n";
        write_file (Filename.concat csrepo (Printf.sprintf "packages/%s/%s.1/opam" apkg apkg)) (Buffer.contents b);
        archpkgs := (arch, apkg) :: !archpkgs)
      (List.rev !archorder)
  end;
  (* init root if needed *)
  let ini = Proc.run opam [ "var"; "root"; "--global" ] in
  if ini.code <> 0 then begin
    let initargs = ref [ "init"; "--bare"; "--no-setup"; "--disable-sandboxing"; "--yes" ] in
    (match winlocs with
     | Some (msys2, git) ->
       initargs := !initargs @ [ "--cygwin-local-install"; "--cygwin-location=" ^ msys2; "--git-location=" ^ git ]
     | None -> ());
    if p.repos <> [] then begin
      let rc = Filename.concat workdir "opamrc-bootstrap" in
      write_file rc (opamrc_body p.repos);
      initargs := !initargs @ [ "--config=" ^ rc ]
    end;
    ignore (Proc.run_checked opam !initargs)
  end;
  (* add repositories (ignore "already exists") *)
  List.iter (fun (name, url) -> ignore (Proc.run opam [ "repository"; "add"; name; url; "--dont-select"; "--yes" ])) p.repos;
  let reponames = ref p.reponames in
  (match !csrepo_url with
   | Some url ->
     ignore (Proc.run opam [ "repository"; "remove"; "dk-solve-constraints-repo"; "--all"; "--yes" ]);
     ignore (Proc.run opam [ "repository"; "add"; "dk-solve-constraints-repo"; url; "--dont-select"; "--yes" ]);
     reponames := !reponames @ [ "dk-solve-constraints-repo" ]
   | None -> ());
  (* create empty switch if absent *)
  let swres = Proc.run opam [ "switch"; "list"; "--short" ] in
  let have = List.mem switch (S.lines swres.stdout) in
  if not have then begin
    let cres = Proc.run opam [ "switch"; "create"; switch; "--empty"; "--repositories=" ^ String.concat "," !reponames; "--yes" ] in
    if cres.code <> 0 then begin
      let se = cres.stderr ^ cres.stdout in
      if not (S.contains_sub ~needle:"already" se) then begin
        Printf.eprintf "[opam-lock] FATAL: could not create switch %s: %s\n" switch se;
        exit 1
      end
    end
  end;
  (match !constraints_pkg with
   | Some c -> Printf.eprintf "[opam-lock] version locks supplied by the %s constraints repository\n" c
   | None -> ());
  (* float removals (skip on a fresh ephemeral switch) *)
  if fresh then
    Printf.eprintf "[opam-lock] skipping float removals: the ephemeral switch has no pins to remove\n"
  else
    List.iter (fun f -> ignore (Proc.run opam [ "pin"; "remove"; "--switch=" ^ switch; "--no-action"; "-y"; f ])) p.floats;
  (match local_opam_dir with
   | Some dir -> ignore (Proc.run_checked opam [ "pin"; "add"; "--switch=" ^ switch; "-n"; "-y"; dir ])
   | None -> ());
  (!constraints_pkg, List.rev !archpkgs, p.repos)

(* --------------------------------------------------------------------- *)
(* discover_locals: package names pinned to a local dir (rsync/path).     *)
(* --------------------------------------------------------------------- *)
let discover_locals ~opam ~switch =
  let r = Proc.run opam [ "pin"; "list"; "--switch=" ^ switch ] in
  List.filter_map
    (fun line ->
      let w = S.words line in
      let is_local = List.exists (fun t -> t = "rsync" || t = "path") w in
      match (is_local, w) with
      | true, first :: _ ->
        (match S.first_dot first with Some d -> Some (String.sub first 0 d) | None -> None)
      | _ -> None)
    (S.lines r.stdout)

(* --------------------------------------------------------------------- *)
(* Per-slot OPAMVAR overrides.                                            *)
(* --------------------------------------------------------------------- *)
let slot_vars = function
  | "Release.Windows_x86_64" -> Some ("win32", "x86_64")
  | "Release.Windows_x86" -> Some ("win32", "x86_32")
  | "Release.Linux_x86_64" -> Some ("linux", "x86_64")
  | "Release.Linux_x86_64_musl" -> Some ("linux", "x86_64")
  | "Release.Linux_x86" -> Some ("linux", "x86_32")
  | "Release.Linux_arm64" -> Some ("linux", "arm64")
  | "Release.Darwin_x86_64" -> Some ("macos", "x86_64")
  | "Release.Darwin_arm64" -> Some ("macos", "arm64")
  | _ -> None

let default_slots =
  [ "Release.Windows_x86_64"; "Release.Windows_x86";
    "Release.Linux_x86_64"; "Release.Linux_x86_64_musl"; "Release.Linux_x86";
    "Release.Linux_arm64";
    "Release.Darwin_x86_64"; "Release.Darwin_arm64" ]

(* --------------------------------------------------------------------- *)
(* The solve.                                                             *)
(* --------------------------------------------------------------------- *)

type opts = {
  opam : string;
  workdir : string;
  pins_file : string;
  switch : string option;         (* None -> ephemeral under workdir *)
  slots : string list;
  roots : string list;
  locals : string list option;    (* None -> auto-discover *)
  local_opam_dir : string option;
  wtest : bool;
  msys2 : string option;
  git : string option;
  repo_commit : string option;
  repo_url : string option;
  tool : string;
  pins_name : string;             (* project-relative pin table name for the stamp *)
}

(* --------------------------------------------------------------------- *)
(* Relocatable override for ocamlfind and ocamlbuild.                     *)
(*                                                                        *)
(* The lock-solver force-overrides these two packages to relocatable      *)
(* builds regardless of what the opam solve resolves, so a prebuilt       *)
(* CommonsBase_Dk.Dk0.Pkg.Ocamlfind / Pkg.Ocamlbuild object carries       *)
(* RELATIVE topfind/findlib.conf (and a relative ocamlbuild libdir) and   *)
(* is consumable when imported into a different build tree. The opam      *)
(* solve still runs (so the closure resolves and both packages still      *)
(* satisfy their dependents at the resolved version), but when the helper *)
(* EMITS these two entries it substitutes the source (dra27's relocatable *)
(* forks, content-addressed by git commit so no moving ref), the build    *)
(* flags (-sitelib "." / OCAMLBUILD_LIBDIR=..) and the install commands    *)
(* from the table below. See CommonsLang_OCaml `dk.u`. *)
type reloc = {
  r_url : string;
  r_sums : string list;   (* at least one sha256= entry (dk bundle checksum) *)
  r_size : int;
  r_archive : string;     (* tgz | txz | tbz | tar | zip *)
  r_build : string;       (* opam `build:` list syntax, as `opam show` emits it *)
  r_install : string;     (* opam `install:` list syntax; "" => no install stanza *)
}

let reloc_override name =
  match name with
  | "ocamlfind" ->
      (* jonahbeckford/ocamlfind = dra27 relocatable (1faecd40, v1.9.8) plus a
         dk-per-package patch that cygpath-normalizes the -with-relative-paths-at
         prefix. Built with -sitelib "." + -with-relative-paths-at %{prefix}%,
         findlib writes a relocatable topfind (findlib_directory = location) and a
         relative findlib.conf (destdir = "$PREFIX/lib"). *)
      Some {
        r_url = "https://github.com/jonahbeckford/ocamlfind/releases/download/1.9.8+reloc+dk/src.tar.gz";
        r_sums = [ "sha256=e47b7711420a5edbd95765ea8a6867bd2f2146f8ee461ac18a6b26d890d762d8" ];
        r_size = 176531;
        r_archive = "tgz";
        (* -sitelib "." makes findlib.conf relative; -with-relative-paths-at
           %{prefix}% makes topfind relocatable (findlib_directory = location)
           and findlib.conf destdir = "$PREFIX/lib" (findlib expands $PREFIX to
           the runtime install location). Both together make the prebuilt
           findlib consumable in another build tree. *)
        r_build =
          "[\n  \"./configure\"\n  \"-bindir\" bin\n  \"-sitelib\" \".\"\n  \"-mandir\" man\n  \"-config\" \"%{lib}%/findlib.conf\"\n  \"-with-relative-paths-at\" \"%{prefix}%\"\n  \"-no-custom\"\n  \"-no-camlp4\" {!ocaml:preinstalled & ocaml:version >= \"4.02.0\"}\n  \"-no-topfind\" {ocaml:preinstalled}\n]\n[make \"all\"]\n[make \"opt\"] {ocaml:native}";
        r_install =
          "[make \"install\"]\n[\"install\" \"-m\" \"0755\" \"ocaml-stub\" \"%{bin}%/ocaml\"] {ocaml:preinstalled}";
      }
  | "ocamlbuild" ->
      (* jonahbeckford/ocamlbuild = dra27 relocatable-0.14.3 (5a1529c3) plus a
         dk-per-package patch that drops configure.make's bindir==compiler-bindir
         gate so relocation engages. Built via configure.make with
         OCAMLBUILD_LIBDIR=.., ocamlbuild_config bakes bindir="." libdir=".." and
         computes the absolute dirs at runtime. *)
      Some {
        r_url = "https://github.com/jonahbeckford/ocamlbuild/releases/download/0.14.3+reloc+dk/src.tar.gz";
        r_sums = [ "sha256=c7cb4009e475f0d08f7b278e651f6d1240cc98597d36c06636efcef54d994e9e" ];
        r_size = 204019;
        r_archive = "tgz";
        r_build =
          "[\n  make \"-f\" \"configure.make\" \"all\"\n  \"OCAMLBUILD_PREFIX=%{prefix}%\"\n  \"OCAMLBUILD_BINDIR=%{bin}%\"\n  \"OCAMLBUILD_LIBDIR=..\"\n  \"OCAMLBUILD_MANDIR=%{man}%\"\n  \"OCAML_NATIVE=%{ocaml:native}%\"\n  \"OCAML_NATIVE_TOOLS=%{ocaml:native}%\"\n]\n[make \"check-if-preinstalled\" \"all\" \"opam-install\"]";
        r_install = "";
      }
  | _ -> None

let do_solve o =
  let workdir = o.workdir in
  let switch, ephemeral =
    match o.switch with
    | Some s -> (s, false)
    | None -> (Filename.concat workdir "solve", true)
  in
  let switchargs = [ "--switch=" ^ switch ] in
  let winlocs = match (o.msys2, o.git) with Some m, Some g -> Some (m, g) | _ -> None in
  let pins =
    let ic = open_in_bin o.pins_file in
    let n = in_channel_length ic in
    let content = really_input_string ic n in
    close_in ic;
    parse_pins content
  in
  let constraints_pkg, archpkgs, repos_decl =
    setup_switch ~opam:o.opam ~switch ~workdir ~pins ~local_opam_dir:o.local_opam_dir ~winlocs ~fresh:ephemeral
  in
  let locals_list =
    match o.locals with Some l -> l | None -> discover_locals ~opam:o.opam ~switch
  in
  let locals_set = List.fold_left (fun acc n -> n :: acc) [] locals_list in
  let is_local name = List.mem name locals_set in
  if o.roots = [] then (Printf.eprintf "[opam-lock] FATAL: at least one root is required\n"; exit 1);
  let rootscsv =
    let base = String.concat "," o.roots in
    match constraints_pkg with Some c -> base ^ "," ^ c | None -> base
  in
  let opamver =
    let r = Proc.run o.opam [ "--version" ] in
    S.trim r.stdout
  in
  (* 1. solve each slot *)
  let all_keys = Hashtbl.create 256 in
  let all_keys_order = ref [] in
  let add_key k = if not (Hashtbl.mem all_keys k) then (Hashtbl.add all_keys k (); all_keys_order := k :: !all_keys_order) in
  let slot_solutions =
    List.map
      (fun slot ->
        Printf.eprintf "[opam-lock] solving slot %s\n" slot;
        let os, arch =
          match slot_vars slot with
          | Some v -> v
          | None -> Printf.eprintf "[opam-lock] FATAL: unknown slot %s\n" slot; exit 1
        in
        let adds = [ ("OPAMVAR_os", os); ("OPAMVAR_arch", arch) ] in
        let slotresolve =
          match List.assoc_opt arch archpkgs with
          | Some apkg -> rootscsv ^ "," ^ apkg
          | None -> rootscsv
        in
        let args =
          [ "list"; "--resolve=" ^ slotresolve; "--columns=package"; "--short" ]
          @ (if o.wtest then [ "--with-test" ] else [])
          @ switchargs
        in
        let r = Proc.run ~adds o.opam args in
        if r.code <> 0 then (Printf.eprintf "[opam-lock] FATAL: solve failed for %s\n%s\n" slot r.stderr; exit 1);
        let keys =
          List.filter
            (fun k ->
              let nm = match S.first_dot k with Some d -> String.sub k 0 d | None -> k in
              not (S.starts_with ~prefix:"dk-solve-" nm))
            (S.lines r.stdout)
        in
        let keys = List.sort String.compare keys in
        List.iter add_key keys;
        (slot, (os, arch), keys))
      o.slots
  in
  (* name -> in closure? *)
  let name_in_closure = Hashtbl.create 256 in
  List.iter
    (fun k -> match S.first_dot k with Some d -> Hashtbl.replace name_in_closure (String.sub k 0 d) () | None -> ())
    (List.rev !all_keys_order);
  (* 2. metadata *)
  let keylist = List.rev !all_keys_order in
  Printf.eprintf "[opam-lock] reading opam metadata for %d packages (batched opam show)\n" (List.length keylist);
  let meta = opam_show_all ~opam:o.opam ~switchargs ~keys:keylist in
  let packages =
    List.map
      (fun ak ->
        let dot = match S.first_dot ak with Some d -> d | None -> String.length ak in
        let name = String.sub ak 0 dot in
        let version = if dot < String.length ak then String.sub ak (dot + 1) (String.length ak - dot - 1) else "" in
        let m = try Hashtbl.find meta ak with Not_found -> [] in
        let field f = try List.assoc f m with Not_found -> "" in
        let url = S.unquote (field "url.src:") in
        let sums = ref (checksums (field "url.checksum:")) in
        let depends_raw = field "depends:" in
        let build_raw = field "build:" in
        let install_raw = field "install:" in
        let depopts_raw = field "depopts:" in
        (* Relocatable override: force ocamlfind/ocamlbuild to the pinned
           relocatable forks + build flags, keeping the solved version/depends. *)
        let ovr = reloc_override name in
        let url = match ovr with Some r -> r.r_url | None -> url in
        let build_raw = match ovr with Some r -> r.r_build | None -> build_raw in
        let install_raw = match ovr with Some r -> r.r_install | None -> install_raw in
        (match ovr with Some r -> sums := r.r_sums | None -> ());
        (* direct deps in closure, discovery order, deduped; then depopts *)
        let depfiltered = top_level_quoted_filtered depends_raw in
        let depnames = List.map fst depfiltered in
        let optnames = top_level_quoted depopts_raw in
        Validator.check ~pkg:ak ~field:"depends" ~scanner:depnames depends_raw;
        if S.trim depopts_raw <> "" then Validator.check ~pkg:ak ~field:"depopts" ~scanner:optnames depopts_raw;
        let seen = Hashtbl.create 16 in
        let depends = ref [] in
        let consider d =
          if Hashtbl.mem name_in_closure d && d <> name && not (Hashtbl.mem seen d) then begin
            Hashtbl.add seen d (); depends := d :: !depends
          end
        in
        (* A test-only edge is dropped, except for a LOCAL package: this closure
           may actually run its tests, so its own with-test dependencies are
           staged. Each occurrence carries its own filter, so a name listed both
           with and without a test filter keeps the edge. *)
        List.iter
          (fun (d, filt) -> if is_local name || not (is_test_only_filter filt) then consider d)
          depfiltered;
        List.iter consider optnames;
        let depends = List.rev !depends in
        let source =
          match ovr with
          | Some r ->
            (* Fixed relocatable source: direct URL (incache=0), pinned
               checksum + size; no cache probing. *)
            Json.Obj
              [ ("url", Json.Str r.r_url);
                ("checksums", Json.Arr (List.map (fun s -> Json.Str s) r.r_sums));
                ("archive", Json.Str r.r_archive);
                ("incache", Json.Int 0);
                ("size", Json.Int r.r_size) ]
          | None ->
          if is_local name || url = "" || !sums = [] then Json.Null
          else begin
            let incache = ref 1 in
            if not (has_bundle_checksum !sums) then begin
              let computed = ref "" in
              (match cache_url !sums with
               | Some cu -> (match source_sha256 ~workdir cu with Some h -> computed := h | None -> ())
               | None -> ());
              if !computed = "" then
                (match source_sha256 ~workdir url with Some h -> computed := h; incache := 0 | None -> ());
              if !computed <> "" then sums := !sums @ [ "sha256=" ^ !computed ]
            end;
            let fields = ref [] in
            fields := ("url", Json.Str url) :: !fields;
            fields := ("checksums", Json.Arr (List.map (fun s -> Json.Str s) !sums)) :: !fields;
            fields := ("archive", Json.Str (archive_type url)) :: !fields;
            if !incache = 0 then fields := ("incache", Json.Int 0) :: !fields;
            let sz =
              if !incache = 1 then
                (match cache_url !sums with Some cu -> (match source_size cu with Some s -> Some s | None -> source_size url) | None -> source_size url)
              else source_size url
            in
            (match sz with Some s when s > 0 -> fields := ("size", Json.Int s) :: !fields | _ -> ());
            Json.Obj !fields
          end
        in
        let opt_raw r = if r <> "" then Json.Str r else Json.Null in
        let base =
          [ ("name", Json.Str name);
            ("version", Json.Str version);
            ("source", source);
            ("depends", Json.Arr (List.map (fun d -> Json.Str d) depends));
            ("depends_raw", opt_raw depends_raw);
            ("build", opt_raw build_raw);
            ("install", opt_raw install_raw) ]
        in
        let base = if is_local name then ("local", Json.Str "t") :: base else base in
        (ak, Json.Obj base))
      keylist
  in
  (* 3. repositories from the pin table *)
  let commit = match o.repo_commit with Some c -> Json.Str c | None -> Json.Null in
  let repos_json =
    if repos_decl <> [] then
      List.map (fun (name, url) -> Json.Obj [ ("name", Json.Str name); ("url", Json.Str url); ("commit", commit) ]) repos_decl
    else
      [ Json.Obj [ ("url", Json.Str (match o.repo_url with Some u -> u | None -> "unknown")); ("commit", commit) ] ]
  in
  (* 4. assemble *)
  let slots_json =
    List.map
      (fun (slot, (os, arch), keys) ->
        ( slot,
          Json.Obj
            [ ("opam_vars", Json.Obj [ ("os", Json.Str os); ("arch", Json.Str arch) ]);
              ("solution", Json.Arr (List.map (fun k -> Json.Str k) keys)) ] ))
      slot_solutions
  in
  let lock =
    Json.Obj
      [ ("$schema", Json.Str "https://diskuv.com/dk/schema/dk-opam-lock-1.0.json");
        ("schema_version", Json.Obj [ ("major", Json.Int 1); ("minor", Json.Int 0) ]);
        ("generated",
         Json.Obj
           ([ ("tool", Json.Str o.tool);
              ("opam_version", Json.Str opamver);
              ("roots", Json.Arr (List.map (fun r -> Json.Str r) o.roots));
              ("pins", Json.Str o.pins_name) ]
            @ (if o.wtest then [ ("wtest", Json.Str "t") ] else [])
            @ (match o.local_opam_dir with
               | Some d -> [ ("local_opam_dir", Json.Str d) ]
               | None -> [])));
        ("opam_repositories", Json.Arr repos_json);
        ("packages", Json.Obj packages);
        ("slots", Json.Obj slots_json) ]
  in
  if ephemeral then ignore (Proc.run o.opam [ "switch"; "remove"; switch; "--yes" ]);
  let body = Json.to_string lock ^ "\n" in
  set_binary_mode_out stdout true;
  output_string stdout body;
  flush stdout;
  Printf.eprintf "[opam-lock] wrote lock (%d packages)\n" (List.length keylist)

(* --------------------------------------------------------------------- *)
(* CLI.                                                                   *)
(* --------------------------------------------------------------------- *)

let selftest () =
  let ok = ref true in
  let check name got want =
    if got <> want then (ok := false; Printf.eprintf "FAIL %s:\n  got  %S\n  want %S\n" name got want)
    else Printf.eprintf "ok   %s\n" name
  in
  (* SHA-256 FIPS vectors *)
  check "sha256(\"\")" (Sha256.digest_string "")
    "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855";
  check "sha256(\"abc\")" (Sha256.digest_string "abc")
    "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad";
  (* longer than one block (56+ bytes) to exercise padding + multi-block *)
  check "sha256(56 chars)"
    (Sha256.digest_string "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq")
    "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1";
  (* JSON encoder shape *)
  check "json empty arr" (Json.to_string (Json.Arr [])) "[]";
  check "json local marker"
    (Json.to_string (Json.Obj [ ("local", Json.Str "t"); ("name", Json.Str "x") ]))
    "{\n  \"local\": \"t\",\n  \"name\": \"x\"\n}";
  check "json crlf escape"
    (Json.to_string (Json.Str "a\r\nb")) "\"a\\r\\nb\"";
  check "json int" (Json.to_string (Json.Int 442762)) "442762";
  (* scanners *)
  let dep = "\"dune\" {>= \"3.18\"}\r\n\"ocaml\" {>= \"4.14\"}\r\n\"MlFront_Logs\" {= version}" in
  check "top_level_quoted" (String.concat "," (top_level_quoted dep)) "dune,ocaml,MlFront_Logs";
  check "checksums"
    (String.concat "," (checksums "\"md5=abc\" \"sha256=def\""))
    "md5=abc,sha256=def";
  check "unquote" (S.unquote "\"https://x\"") "https://x";
  check "archive tgz" (archive_type "https://x/v1.tar.gz") "tgz";
  check "archive tbz" (archive_type "https://x/c-1.3.0.tbz") "tbz";
  (* pins *)
  let pf = parse_pins "# c\nrepo r1 u1\npin p1 1.0\nfloat f1\narchexclude e1 x86_32\n" in
  check "pins repo" (String.concat "," (List.map fst pf.repos)) "r1";
  check "pins pin" (String.concat "," (List.map fst pf.pinned)) "p1";
  check "pins float" (String.concat "," pf.floats) "f1";
  check "pins arch" (String.concat "," (List.map snd pf.archexcludes)) "x86_32";
  (* relocatable override: both packages resolve and carry the relocation
     flags; a non-overridden package returns None *)
  let has_sub hay needle =
    let lh = String.length hay and ln = String.length needle in
    let rec go i = i + ln <= lh && (String.sub hay i ln = needle || go (i + 1)) in
    ln = 0 || go 0
  in
  (match reloc_override "ocamlfind" with
   | Some r ->
     check "reloc ocamlfind sitelib" (if has_sub r.r_build "\"-sitelib\" \".\"" then "y" else "n") "y";
     check "reloc ocamlfind url" (if has_sub r.r_url "jonahbeckford/ocamlfind" then "y" else "n") "y"
   | None -> ok := false; Printf.eprintf "FAIL reloc ocamlfind: None\n");
  (match reloc_override "ocamlbuild" with
   | Some r ->
     check "reloc ocamlbuild libdir" (if has_sub r.r_build "OCAMLBUILD_LIBDIR=.." then "y" else "n") "y"
   | None -> ok := false; Printf.eprintf "FAIL reloc ocamlbuild: None\n");
  check "reloc passthrough" (match reloc_override "fmt" with Some _ -> "some" | None -> "none") "none";
  if !ok then (Printf.eprintf "selftest: PASS\n"; exit 0)
  else (Printf.eprintf "selftest: FAIL\n"; exit 1)

let () =
  let argv = Sys.argv in
  if Array.length argv >= 2 && argv.(1) = "selftest" then selftest ();
  if Array.length argv < 2 || argv.(1) <> "solve" then begin
    Printf.eprintf "usage: dk_opam_lock (solve <opts> | selftest)\n";
    exit 2
  end;
  let opam = ref "" and workdir = ref "" and pins_file = ref "" in
  let switch = ref None and slots = ref [] and roots = ref [] in
  let locals = ref None and local_opam_dir = ref None in
  let wtest = ref false and msys2 = ref None and git = ref None in
  let repo_commit = ref None and repo_url = ref None in
  let tool = ref "CommonsLang_OCaml.Dk.OpamLock@1.0.0" in
  let pins_name = ref "" in
  let add r v = r := !r @ [ v ] in
  let addo r v = r := Some (match !r with Some l -> l @ [ v ] | None -> [ v ]) in
  let spec =
    [ ("--opam", Arg.Set_string opam, "opam executable (required)");
      ("--work-dir", Arg.Set_string workdir, "sandbox work dir (required)");
      ("--pins-file", Arg.Set_string pins_file, "pin table path (required)");
      ("--switch", Arg.String (fun s -> switch := Some s), "reuse a named switch");
      ("--slot", Arg.String (add slots), "output slot (repeatable)");
      ("--root", Arg.String (add roots), "root package (repeatable, required)");
      ("--local", Arg.String (addo locals), "local package name (repeatable)");
      ("--local-opam-dir", Arg.String (fun s -> local_opam_dir := Some s), "dir of local *.opam");
      ("--wtest", Arg.Set wtest, "include test-only deps");
      ("--msys2", Arg.String (fun s -> msys2 := Some s), "MSYS2 dir (Windows hermetic init)");
      ("--git", Arg.String (fun s -> git := Some s), "git cmd dir (Windows hermetic init)");
      ("--repo-commit", Arg.String (fun s -> repo_commit := Some s), "recorded repo commit");
      ("--repo-url", Arg.String (fun s -> repo_url := Some s), "fallback repo url");
      ("--tool", Arg.Set_string tool, "generated.tool string");
      ("--pins-name", Arg.Set_string pins_name, "project-relative pin table name (stamped into generated.pins)") ]
  in
  Arg.parse_argv (Array.sub argv 1 (Array.length argv - 1)) spec
    (fun a -> Printf.eprintf "unexpected argument: %s\n" a; exit 2)
    "dk_opam_lock solve <opts>";
  if !opam = "" || !workdir = "" || !pins_file = "" then
    (Printf.eprintf "[opam-lock] FATAL: --opam, --work-dir and --pins-file are required\n"; exit 1);
  if !roots = [] then (Printf.eprintf "[opam-lock] FATAL: at least one --root is required\n"; exit 1);
  let slots = if !slots = [] then default_slots else !slots in
  do_solve
    { opam = !opam; workdir = !workdir; pins_file = !pins_file; switch = !switch;
      slots; roots = !roots; locals = !locals; local_opam_dir = !local_opam_dir;
      wtest = !wtest; msys2 = !msys2; git = !git;
      repo_commit = !repo_commit; repo_url = !repo_url; tool = !tool;
      pins_name = (if !pins_name = "" then Filename.basename !pins_file else !pins_name) }
