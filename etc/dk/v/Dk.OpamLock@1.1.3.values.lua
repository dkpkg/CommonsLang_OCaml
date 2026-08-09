local M = {
  id = "CommonsLang_OCaml.Dk.OpamLock@1.1.3"
}

-- lua-ml does not support local functions, and a "local" variable would be nil
-- inside the rules/uirules function bodies. So a should-be-unique global table
-- holds the helpers, matching the house style in CommonsBase_Std.Extract and
-- CommonsBase_Remote.GitHub.
CommonsLang_OCaml__Dk_OpamLock__1_1_3 = {}

rules, uirules = build.newrules(M)

-- lua-ml's string library does not implement gsub, so trim by scanning for the
-- first/last non-space with find (which does support patterns).
function CommonsLang_OCaml__Dk_OpamLock__1_1_3.iswhite(c)
  local b = string.byte(c)
  return b == 32 or b == 9 or b == 13 or b == 10
end

-- Explicit whitespace checks (space/tab/CR/LF by byte value: raw control
-- bytes and \r are unrepresentable in lua-ml string literals): lua-ml's %s
-- class does not match CR, which left a trailing CR on every line of CRLF
-- opam output on Windows (ex. the
-- switch-exists check compared name-plus-CR ~= name and re-created the
-- switch).
function CommonsLang_OCaml__Dk_OpamLock__1_1_3.trim(s)
  if s == nil then return "" end
  local n = string.len(s)
  local a = 1
  while a <= n and CommonsLang_OCaml__Dk_OpamLock__1_1_3.iswhite(string.sub(s, a, a)) do a = a + 1 end
  if a > n then return "" end
  local b = n
  while b >= 1 and CommonsLang_OCaml__Dk_OpamLock__1_1_3.iswhite(string.sub(s, b, b)) do b = b - 1 end
  return string.sub(s, a, b)
end

-- Join an ARRAY's elements in index order. Iterating with next() (as an earlier
-- version did) walks lua-ml's arbitrary hash order, which silently scrambled the
-- order of every joined array -- including the JSON encoder's `parts`, so a
-- sorted key list still emitted unsorted. Walk 1..n instead.
function CommonsLang_OCaml__Dk_OpamLock__1_1_3.join(tbl, sep)
  local r = nil
  local i = 1
  while tbl[i] ~= nil do
    if r == nil then
      r = tostring(tbl[i])
    else
      r = r .. sep .. tostring(tbl[i])
    end
    i = i + 1
  end
  if r == nil then return "" end
  return r
end

function CommonsLang_OCaml__Dk_OpamLock__1_1_3.set_from_list(tbl)
  local set = {}
  if tbl == nil then return set end
  -- Store the value itself (not the boolean true): lua-ml does not reliably
  -- persist/iterate `true` table values.
  local k, v = next(tbl)
  while k do set[tostring(v)] = tostring(v); k, v = next(tbl, k) end
  return set
end

-- Directory part of a path (everything before the last '/' or '\'), or "." if
-- the path has no separator. Byte-based (47='/', 92='\\') so it is correct for
-- both the POSIX and Windows realpath forms request.io.realpath can return.
function CommonsLang_OCaml__Dk_OpamLock__1_1_3.dirname(p)
  local i = string.len(p)
  while i >= 1 do
    local b = string.byte(p, i)
    if b == 47 or b == 92 then return string.sub(p, 1, i - 1) end
    i = i - 1
  end
  return "."
end

-- No-op build rule. A CommonsLang_OCaml distribution script exports a
-- scriptmodule by running one of its rules ("running one rule brings in the
-- entire script module"). This scriptmodule otherwise has only the author-time
-- uirule uirules.Solve, which a non-interactive distribution cannot run, so this
-- trivial function rule gives the distribution something to run, causing the
-- whole scriptmodule (including uirules.Solve) to ship and be runnable from an
-- import. Its output is an empty marker; it does nothing else.
function rules.Export(command, request)
  local slots = {
    "Release.Windows_x86_64", "Release.Windows_x86", "Release.Windows_arm64",
    "Release.Darwin_x86_64", "Release.Darwin_arm64",
    "Release.Linux_x86_64", "Release.Linux_x86_64_musl", "Release.Linux_arm64",
    "Release.Linux_x86"
  }
  if command == "declareoutput" then
    return {
      declareoutput = {
        return_objects = {
          id = "CommonsLang_OCaml.Dk.OpamLock.Export@1.1.1",
          slots = slots,
          execution_slot = "Release.execution_abi"
        }
      }
    }
  elseif command == "submit" then
    return {
      submit = {
        values = {
          schema_version = { major = 1, minor = 0 },
          forms = {
            {
              id = request.submit.outputid,
              function_ = {
                commands = {
                  "$(get-object CommonsBase_Std.Coreutils@0.6.0 -s ${SLOTNAME.Release.execution_abi} -m ./coreutils.exe -f coreutils.exe -e '*')",
                  "touch",
                  "${SLOT.request}/opamlock-scriptmodule"
                }
              },
              outputs = {
                assets = { { slots = slots, paths = { "opamlock-scriptmodule" } } }
              }
            }
          }
        }
      }
    }
  end
end


-- Pick the opam binary and run the OCaml helper (assets/opam-lock/dk_opam_lock.ml,
-- compiled against the vendored opam-file-format amalgam by the materialized DkML
-- toolchain). The heavy logic -- opam field parsing, dependency reshaping, source
-- probing, JSON encoding -- lives in the helper where it is testable and free of
-- the lua-ml footguns; this rule only materializes the toolchain, compiles and
-- runs the helper, and publishes its stdout as the lock. Mirrors the thin
-- CommonsLang_Python.UvLock.Solve design.
function uirules.Solve(command, request, continue_)
  local H = CommonsLang_OCaml__Dk_OpamLock__1_1_3
  if command == "ui" then
    print("CommonsLang_OCaml.Dk.OpamLock@1.1.3: lock written.")
    return
  end
  if command ~= "submit" then return end

  local iswin = nil
  if request.execution and request.execution.OSFamily == "windows" then iswin = 1 end

  if continue_ ~= "solve" then
    -- Stage 1: materialize the DkML compiler (ocamlc/ocamlrun + stdlib + unix),
    -- the two helper source assets, and -- unless opam= was given -- opam plus
    -- (on Windows) the MSYS2 tree and MinGit for the hermetic opam init. The
    -- compiler is a build-time tool, so it uses the execution ABI slot.
    local dirs = {
      dkml = "$(get-object CommonsLang_OCaml.DkML@4.14.3 -s Release.execution_abi -d : -e 'bin/*' -e 'lib/ocaml/*')"
    }
    if request.user.opam == nil then
      dirs.opam = "$(get-object CommonsLang_OCaml.Opam@2.5.1 -s Release.execution_abi -d :)"
      if iswin then
        dirs.msys2 = "$(get-object CommonsLang_OCaml.MSYS2@2026.6.11 -s Release.Windows_x86_64 -d :)"
        dirs.git = "$(get-object CommonsBase_Build.Git.MinGit@2.55.0 -s Release.execution_abi -d :)"
      end
    end
    local files = {
      helper = "$(get-asset CommonsLang_OCaml.Apparatus.OpamLockHelper@1.0.2 -p assets/opam-lock/dk_opam_lock.ml -f dk_opam_lock.ml)",
      amalgam = "$(get-asset CommonsLang_OCaml.Apparatus.OpamFileFormat@1.0.2 -p assets/opam-lock/opam_file_format.ml -f opam_file_format.ml)"
    }
    return {
      submit = {
        expressions = { directories = dirs, files = files },
        andthen = { continue_ = { state = "solve" } }
      }
    }
  end

  -- Stage 2. Resolve every continued object to a real path, then close each one
  -- (leaving one open fails the continuation finalizer).
  local exe = ""
  if iswin then exe = ".exe" end
  local dkmldir = H.trim(request.io.realpath(request.continued.dkml))
  local helper = H.trim(request.io.realpath(request.continued.helper))
  local amalgam = H.trim(request.io.realpath(request.continued.amalgam))
  request.io.close(request.continued.dkml)
  request.io.close(request.continued.helper)
  request.io.close(request.continued.amalgam)

  local opamexe
  if request.user.opam then
    opamexe = request.user.opam
  else
    opamexe = H.trim(request.io.realpath(request.continued.opam)) .. "/bin/opam" .. exe
    request.io.close(request.continued.opam)
  end
  local msys2 = nil
  local git = nil
  if request.continued.msys2 then
    msys2 = H.trim(request.io.realpath(request.continued.msys2))
    git = H.trim(request.io.realpath(request.continued.git)) .. "/cmd"
    request.io.close(request.continued.msys2)
    request.io.close(request.continued.git)
  end

  -- Anchor a short work directory in the sandbox (Windows MAX_PATH).
  local anchor = assert(request.io.open("opamlock.anchor", "w"),
    "could not open a sandbox anchor")
  request.io.flush(anchor)
  local workdir = H.dirname(H.trim(request.io.realpath(anchor)))
  request.io.close(anchor)

  -- Copy the project pin table into the sandbox. request.ui.readfile reads the
  -- checked-in project tree (request.io reads the sandbox); the helper then
  -- reads it as an ordinary file.
  local pinsproj = request.user.pins or "dk-opam-pins.txt"
  local pincontent = assert(request.ui.readfile { path = pinsproj },
    "could not read pin table `" .. pinsproj .. "`")
  local pf = assert(request.io.open("dk-opam-pins.txt", "w"),
    "could not open the sandbox pin copy")
  request.io.write(pf, pincontent)
  request.io.flush(pf)
  local pinsfile = H.trim(request.io.realpath(pf))
  request.io.close(pf)

  -- Compile the helper with the materialized DkML compiler. OCAMLLIB points the
  -- relocatable compiler and runtime at their own stdlib (the helper strips it
  -- before spawning opam/curl). The generated amalgam compiles with -w -a.
  -- The two get-asset files materialize into SEPARATE sandbox dirs and ocamlc
  -- runs with cwd = the project dir, so each source's dir must be on the load
  -- path (-I) or the helper fails "Unbound module Opam_file_format": the
  -- amalgam's .cmi lands next to its .ml, not in the cwd.
  local ocamlc = dkmldir .. "/bin/ocamlc" .. exe
  local ocamlrun = dkmldir .. "/bin/ocamlrun" .. exe
  local bc = workdir .. "/dk_opam_lock.bc"
  local cenv = { "+OCAMLLIB=" .. dkmldir .. "/lib/ocaml" }
  print("+ " .. ocamlc .. " -w -a -I <amalgamdir> -I <helperdir> unix.cma <amalgam> <helper> -o " .. bc)
  local cres = request.ui.capture {
    program = ocamlc,
    args = { "-w", "-a",
      "-I", H.dirname(amalgam), "-I", H.dirname(helper),
      "unix.cma", amalgam, helper, "-o", bc },
    envmods = cenv,
    max_output_bytes = 16777211
  }
  assert(cres, "could not run ocamlc")
  assert(cres.status == "exit" and cres.code == 0,
    "could not compile the opam-lock helper: " .. tostring(cres.stderr))

  -- Build the helper argv.
  local args = { bc, "solve", "--opam", opamexe, "--work-dir", workdir, "--pins-file", pinsfile,
    "--tool", "CommonsLang_OCaml.Dk.OpamLock@1.1.3" }
  local out = request.user.out or "dk.opam-lock.jsonc"
  if request.user.switch then table.insert(args, "--switch"); table.insert(args, request.user.switch) end
  if request.user.local_opam_dir then table.insert(args, "--local-opam-dir"); table.insert(args, request.user.local_opam_dir) end
  if request.user.wtest ~= nil then table.insert(args, "--wtest") end
  if request.user.repo_commit then table.insert(args, "--repo-commit"); table.insert(args, request.user.repo_commit) end
  if request.user.repo_url then table.insert(args, "--repo-url"); table.insert(args, request.user.repo_url) end
  if msys2 then
    table.insert(args, "--msys2"); table.insert(args, msys2)
    table.insert(args, "--git"); table.insert(args, git)
  end
  local roots = assert(request.user.roots,
    "please provide 'roots[]=PKG1' 'roots[]=PKG2' ... (the executable packages to lock)")
  assert(type(roots) == "table", "roots must be a table: 'roots[]=PKG1' 'roots[]=PKG2' ...")
  local ri = 1
  while roots[ri] ~= nil do table.insert(args, "--root"); table.insert(args, roots[ri]); ri = ri + 1 end
  local slots = request.user.slots or H.DKML_SLOTS
  assert(type(slots) == "table", "slots must be a table: 'slots[]=SLOT1' 'slots[]=SLOT2' ...")
  local si = 1
  while slots[si] ~= nil do table.insert(args, "--slot"); table.insert(args, slots[si]); si = si + 1 end
  local locals = request.user.locals
  if locals then
    local li = 1
    while locals[li] ~= nil do table.insert(args, "--local"); table.insert(args, locals[li]); li = li + 1 end
  end

  print("[opam-lock] running the helper (it drives opam and writes the lock to stdout)")
  local result = request.ui.capture {
    program = ocamlrun,
    args = args,
    envmods = cenv,
    max_output_bytes = 16777211
  }
  assert(result, "could not run the opam-lock helper")
  assert(result.status == "exit" and result.code == 0,
    "opam-lock helper failed (code " .. tostring(result.code) .. "): " .. tostring(result.stderr))

  -- Record the OCaml compiler module the lock is built with as a top-level
  -- `ocaml` field, so a consumer of an imported package can gate on compiler
  -- compatibility (dk.u "## Resolution of imports"). The helper solves opam
  -- packages and does not know dk toolchain modules, so inject the field here.
  -- Default to the pinned DkML compiler; `ocaml=<full module id>` overrides.
  local ocamlmod = request.user.ocaml
  if ocamlmod == nil then ocamlmod = "CommonsLang_OCaml.DkML@4.14.3" end
  local content = result.stdout
  local brace = string.find(content, "{")
  assert(brace ~= nil, "opam-lock helper output is not a JSON object")
  content = string.sub(content, 1, brace)
    .. "\n  \"ocaml\": \"" .. ocamlmod .. "\","
    .. string.sub(content, brace + 1)

  -- Publish the lock into the checked-in project tree with a compare-and-swap
  -- guard (absent on first generation, else unchanged since the checksum just
  -- taken), so a concurrent writer is never silently clobbered.
  local meta = request.ui.checksum { path = out }
  local expected = "false"
  if meta and meta.sha256 then expected = meta.sha256 end
  local ok, written = request.ui.writefile { path = out, content = content, expected_sha256 = expected }
  assert(ok, "could not write opam lock to `" .. out .. "`: " .. tostring(written))
  print("wrote opam lock to " .. tostring(written))
  return { submit = {} }
end

-- ---------------------------------------------------------------------------
-- GenerateDriver: lock -> driver values file
-- ---------------------------------------------------------------------------

-- Index of the first occurrence of the single character `ch` in `s`, or nil.
-- (string.find treats `.` as a pattern wildcard, so scan by byte instead.)
function CommonsLang_OCaml__Dk_OpamLock__1_1_3.indexof_char(s, ch)
  local i = 1
  local n = string.len(s)
  while i <= n do
    if string.sub(s, i, i) == ch then return i end
    i = i + 1
  end
  return nil
end

-- Decimal digits of a lua-ml number (no string.format; concat of a number is
-- unreliable). Mirrors CommonsBase_Dk.Dk0Build.numstr.
function CommonsLang_OCaml__Dk_OpamLock__1_1_3.numstr(v)
  if type(v) == "string" then return v end
  if type(v) ~= "number" then return tostring(v) end
  if v == 0 then return "0" end
  local n = v
  local digits = ""
  while n >= 1 do
    local d = n % 10
    local di = d - (d % 1)
    digits = string.sub("0123456789", di + 1, di + 1) .. digits
    n = (n - d) / 10
  end
  return digits
end

-- An opam package name as a dk namespace term segment ([A-Z][a-z0-9_]*):
-- `-`/`.` become `_`, the first character is uppercased and the rest
-- lowercased. MUST match the modsegment transform in the per-package build
-- rule (CommonsBase_Dk.Dk0Build), which derives sibling Pkg object ids from
-- dependency names with the same function.
function CommonsLang_OCaml__Dk_OpamLock__1_1_3.modsegment(name)
  local out = ""
  local i = 1
  local n = string.len(name)
  while i <= n do
    local c = string.sub(name, i, i)
    if c == "-" or c == "." then c = "_" end
    if i == 1 then c = string.upper(c) else c = string.lower(c) end
    out = out .. c
    i = i + 1
  end
  return out
end

-- Packages provided by the DkML toolchain objects or purely virtual: never
-- built as Pkg objects, so the driver never chains them. The default for
-- GenerateDriver's provided[] parameter; a project on another toolchain
-- passes its own list. Mirrors PROVIDED in CommonsBase_Dk.Dk0Build.
CommonsLang_OCaml__Dk_OpamLock__1_1_3.DKML_PROVIDED = {
  "ocaml", "ocaml-base-compiler", "ocaml-config", "ocaml-options-vanilla",
  "base-unix", "base-threads", "base-bigarray", "dune", "flexdll",
  "conf-mingw-w64-gcc-x86_64", "host-arch-x86_64", "host-arch-x86_32",
  "host-arch-arm64", "host-system-mingw", "host-system-other"
}

-- The 8 DkML slots; the default for GenerateDriver's slots[] parameter.
CommonsLang_OCaml__Dk_OpamLock__1_1_3.DKML_SLOTS = {
  "Release.Windows_x86_64", "Release.Windows_x86",
  "Release.Linux_x86_64", "Release.Linux_x86_64_musl", "Release.Linux_x86",
  "Release.Linux_arm64",
  "Release.Darwin_x86_64", "Release.Darwin_arm64"
}

-- Depth-first post-order walk of `name`'s dependencies in the lock, appending
-- each buildable package to `order` after its dependencies. `seen` is marked
-- before recursing (opam dependency graphs are acyclic, so no cycle check).
-- A dependency with neither a source nor the local mark (a virtual package
-- such as `seq`) is skipped; a dependency absent from the lock is an error.
function CommonsLang_OCaml__Dk_OpamLock__1_1_3.driver_visit(byname, provided, name, seen, order)
  local H = CommonsLang_OCaml__Dk_OpamLock__1_1_3
  if seen[name] ~= nil or provided[name] ~= nil then return end
  local e = byname[name]
  assert(e ~= nil, "dependency `" .. name .. "` is not in the lock")
  seen[name] = name
  if type(e.source) ~= "table" and e["local"] ~= "t" then return end
  local i = 1
  while e.depends ~= nil and e.depends[i] ~= nil do
    H.driver_visit(byname, provided, e.depends[i], seen, order)
    i = i + 1
  end
  table.insert(order, name)
end

-- Generate the per-package driver values file from a checked-in opam lock: a
-- form whose sequential precommands run-function the per-package build rule
-- for every package in the root's dependency closure, in topological order,
-- so each package becomes its own content-addressed dk object and the final
-- run-function produces the root. Author-time companion to Solve: re-run it
-- whenever the lock changes.
--
-- Parameters (dk0 dialog CommonsLang_OCaml.Dk.OpamLock.GenerateDriver@1.1.1):
--   lock=PATH          project-relative lock file (the Solve output)
--   out=PATH           project-relative driver values file to write
--   root=PKG           opam package whose closure is chained (built last,
--                      into the `built` directory). Provide root= OR roots[]=.
--   'roots[]=PKG ...'  multiple root packages whose combined closure is built
--                      (the union walked in topological order). Use for a
--                      test-dependency closure with no single executable root;
--                      pair with mergedprefix=t (there is no `built` root).
--   'skiplocal=t'      omit packages marked "local":"t" from the emitted chain
--                      (they are built in-tree by the consumer, e.g. MlFront's
--                      own dune build), building only their external closure.
--   'mergedprefix=t'   the final function merges EVERY built package's
--                      install.zip into one prefix `p/` (+ the seq META stub)
--                      and outputs prefix.zip, instead of copying a single
--                      root's install.zip. All packages build into p<i> dirs.
--   formid=ID@VER      the driver form id (ex. the module CommonsBase_Dk.Dk0
--                      at version 2.4.2)
--   pkgpath=MODPATH    module path under which Pkg objects live
--                      (ex. pkgpath=CommonsBase_Dk.Dk0 places csexp at
--                      CommonsBase_Dk.Dk0.Pkg.Csexp)
--   version=VER        version of the Pkg objects
--   rulefn=ID@VER      the per-package build rule
--                      (ex. CommonsLang_OCaml.Dk.OpamBuild.F_BuildLockedPackage@1.0.0)
--   localsrc=ID@VER    the shared localized-source object, threaded onto every
--                      precommand: it carries both the lock (read from
--                      locksrcpath= inside it) and, for a package marked
--                      "local":"t", the in-tree source
--   locksrcpath=PATH   top-level member path of the lock in localsrc
--                      (ex. "./dk-opam-lock.jsonc")
--   'prelude[]=...'    optional raw precommand lines inserted before the
--                      chain (ex. the localize run-function that produces a
--                      shared local-package source object)
--   'provided[]=...'   optional toolchain-provided package names to skip
--                      (default: the DkML set)
--   'slots[]=...'      optional output slots (default: the 7 DkML slots)
--   'parallel=t'       optional: emit unordered precommands + per-package deps[]
--                      edges for concurrent builds (default: a sequential chain)
function uirules.GenerateDriver(command, request)
  local H = CommonsLang_OCaml__Dk_OpamLock__1_1_3
  if command == "ui" then
    print("CommonsLang_OCaml.Dk.OpamLock@1.1.3: driver written.")
    return
  end
  if command ~= "submit" then return end

  local lockpath = assert(request.user.lock, "please provide 'lock=PROJECT_RELATIVE_LOCK_PATH'")
  local out = assert(request.user.out, "please provide 'out=PROJECT_RELATIVE_DRIVER_PATH'")
  -- Roots: a single root=PKG (chained, built last into `built`) or roots[]=PKG
  -- ... (the union closure). At least one is required; root= stays the
  -- backward-compatible single-root spelling.
  local root = request.user.root
  local roots = request.user.roots
  if roots == nil and root ~= nil then roots = { root } end
  assert(roots ~= nil and roots[1] ~= nil,
    "please provide 'root=PKG' or 'roots[]=PKG1' 'roots[]=PKG2' ...")
  assert(type(roots) == "table", "roots must be a table: 'roots[]=PKG1' 'roots[]=PKG2' ...")
  -- skiplocal=t drops "local":"t" packages from emission; mergedprefix=t merges
  -- every built install.zip into one prefix.zip. Both presence-truthy, additive:
  -- an existing single-root regen passes neither and is byte-unchanged.
  local skiplocal = request.user.skiplocal
  local mergedprefix = request.user.mergedprefix
  -- The single-root model copies one `built/install.zip`, so it cannot express
  -- more than one root; multiple roots require the mergedprefix merge.
  if mergedprefix == nil and roots[2] ~= nil then
    assert(false, "roots[] with more than one package requires mergedprefix=t (the single-root model chains into `built`)")
  end
  local formid = assert(request.user.formid, "please provide 'formid=MODULE@VERSION'")
  local pkgpath = assert(request.user.pkgpath, "please provide 'pkgpath=MODULE_PATH' (ex. CommonsBase_Dk.Dk0)")
  local version = assert(request.user.version, "please provide 'version=VER' (ex. 2.4.2)")
  local rulefn = assert(request.user.rulefn, "please provide 'rulefn=MODULE.FN@VERSION'")
  local localsrc = assert(request.user.localsrc, "please provide 'localsrc=MODULE@VERSION'")
  local locksrcpath = assert(request.user.locksrcpath, "please provide 'locksrcpath=PATH' (the lock's path inside localsrc)")
  local prelude = request.user.prelude
  local provided = H.set_from_list(request.user.provided)
  if next(provided) == nil then provided = H.set_from_list(H.DKML_PROVIDED) end
  local slots = request.user.slots
  if slots == nil then slots = H.DKML_SLOTS end
  -- Parallel mode (parallel=t): emit unordered precommands with per-package
  -- deps[] edges so the engine's two-pass dispatch schedules independent
  -- packages concurrently. Absent, the driver stays a sequential chain that
  -- needs no edges (the historical default), so existing regens are unchanged.
  local parallel = request.user.parallel

  local content = assert(request.ui.readfile { path = lockpath },
    "could not read lock `" .. lockpath .. "`")
  local jd = require("jsondk")
  local lock = jd.decode(content)
  assert(lock and lock.packages, "could not decode the lock (no packages)")

  -- Lock keys are `name.version`; index entries by bare name.
  local byname = {}
  local k = next(lock.packages)
  while k do
    local dot = H.indexof_char(k, ".")
    if dot ~= nil then byname[string.sub(k, 1, dot - 1)] = lock.packages[k] end
    k = next(lock.packages, k)
  end

  -- Import sources: prebuilt Pkg objects the driver consumes instead of building a
  -- matching package locally (see dk.u "## Resolution of imports"). The caller
  -- passes three parallel lists per source: implib[]=<Namespace> (ex.
  -- CommonsBase_Dk.Dk0.Pkg), impver[]=<module version> (ex. 2.4.2), and
  -- impsrclock[]=<path to that source's own opam lock>. A package is imported from
  -- the first source that was built with the same `ocaml` compiler as this lock and
  -- pins the package at the same opam version; every other package is built here.
  local gate_ocaml = lock.ocaml
  if gate_ocaml == nil then gate_ocaml = "CommonsLang_OCaml.DkML@4.14.3" end
  local imported = {}   -- bare opam name -> fully-qualified imported object id
  local implibs = request.user.implib
  local impvers = request.user.impver
  local impsrclocks = request.user.impsrclock
  if implibs ~= nil then
    assert(type(implibs) == "table" and type(impvers) == "table" and type(impsrclocks) == "table",
      "implib[]/impver[]/impsrclock[] must be parallel lists")
    local xi = 1
    while implibs[xi] ~= nil do
      local slib = implibs[xi]
      local sver = assert(impvers[xi], "impver[] shorter than implib[]")
      local spath = assert(impsrclocks[xi], "impsrclock[] shorter than implib[]")
      local scontent = assert(request.ui.readfile { path = spath },
        "could not read import srclock `" .. spath .. "`")
      local slock = jd.decode(scontent)
      assert(slock and slock.packages, "import srclock has no packages: " .. spath)
      local socaml = slock.ocaml
      if socaml == nil then socaml = "CommonsLang_OCaml.DkML@4.14.3" end
      -- Compiler must match for the compiled .cmi/.cmxa to be consumable.
      if socaml == gate_ocaml then
        local sbyver = {}
        local sk = next(slock.packages)
        while sk do
          local sd = H.indexof_char(sk, ".")
          if sd ~= nil then sbyver[string.sub(sk, 1, sd - 1)] = string.sub(sk, sd + 1) end
          sk = next(slock.packages, sk)
        end
        local gk = next(lock.packages)
        while gk do
          local gd = H.indexof_char(gk, ".")
          if gd ~= nil then
            local gname = string.sub(gk, 1, gd - 1)
            local gver = string.sub(gk, gd + 1)
            -- Never import a local ("local":"t") package under skiplocal: it is the
            -- source under test and must be built in-tree from the localized source,
            -- not consumed from a base's PREVIOUS release (which would test stale
            -- code, and for a base-exclusive namespace like Dk1.Pkg.Dkone_exec is not
            -- even published under a Dk0.Pkg base). Its external deps still import.
            local g_is_local = byname[gname] ~= nil and byname[gname]["local"] == "t"
            if imported[gname] == nil and sbyver[gname] == gver
               and not (skiplocal ~= nil and g_is_local) then
              -- `slib` is the full object namespace (ex. CommonsBase_Dk.Dk0.Pkg),
              -- so the id is `<slib>.<Seg>@<ver>` -- do NOT insert another `.Pkg`.
              imported[gname] = slib .. "." .. H.modsegment(gname) .. "@" .. sver
            end
          end
          gk = next(lock.packages, gk)
        end
      end
      xi = xi + 1
    end
  end

  -- Union the topological closure of every root through the shared seen/order
  -- (driver_visit dedups and post-orders, so multiple roots compose correctly).
  local order = {}
  local seen = {}
  local ri = 1
  while roots[ri] ~= nil do
    H.driver_visit(byname, provided, roots[ri], seen, order)
    ri = ri + 1
  end
  assert(order[1] ~= nil, "the requested root(s) have no buildable closure in the lock")

  -- The packages actually EMITTED as Pkg objects: the whole closure, minus the
  -- "local":"t" packages when skiplocal=t (their external deps stay -- they are
  -- earlier in the post-order -- only the locals themselves are dropped). A local
  -- root is still walked above (to reach its deps); skiplocal only elides its own
  -- run-function line.
  local emit = {}
  local eo = 1
  while order[eo] ~= nil do
    local nm = order[eo]
    local is_local = byname[nm] ~= nil and byname[nm]["local"] == "t"
    -- Imported packages are consumed as prebuilt objects, never emitted as a local
    -- build form (their install.zip is merged in below via get-object instead).
    if imported[nm] == nil and not (skiplocal ~= nil and is_local) then table.insert(emit, nm) end
    eo = eo + 1
  end
  assert(emit[1] ~= nil, "nothing to build after skiplocal dropped the local packages")

  -- Buildable-closure membership so parallel deps[] edges point only at emitted
  -- Pkg objects; provided/virtual (and skiplocal-dropped) deps are excluded.
  local inorder = {}
  local mi = 1
  while emit[mi] ~= nil do inorder[emit[mi]] = emit[mi]; mi = mi + 1 end
  local seqflag = "true"
  if parallel ~= nil then seqflag = "false" end

  -- Emit the driver as JSONC. Concatenate in index order (the module `join`
  -- iterates with next(), which scrambles array order).
  local nl = "\n"
  -- Header label works for a single root= or multiple roots[]= (root may be nil).
  local rootlabel = root or H.join(roots, ", ")
  local body = "// Driver for the per-package opam build of `" .. rootlabel .. "`: run-functions the" .. nl
    .. "// per-package build rule for every package in the root's dependency closure in" .. nl
    .. "// topological order, so each package is its own content-addressed dk object" .. nl
    .. "// and an interrupted build resumes from the completed objects." .. nl
    .. "//" .. nl
    .. "// GENERATED by the CommonsLang_OCaml.Dk.OpamLock.GenerateDriver dialog from" .. nl
    .. "// `" .. lockpath .. "`. Regenerate (do not hand-edit) when the lock changes." .. nl
    .. "{" .. nl
    .. "  \"$schema\": \"https://diskuv.com/dk/schema/dk-value-1.0.json\"," .. nl
    .. "  \"schema_version\": { \"major\": 1, \"minor\": 0 }," .. nl
    .. "  \"forms\": [" .. nl
    .. "    {" .. nl
    .. "      \"id\": \"" .. formid .. "\"," .. nl
    .. "      \"precommands\": {" .. nl
    .. "        \"sequential\": " .. seqflag .. "," .. nl
    .. "        \"private\": [" .. nl
  local lines = {}
  local pi = 1
  while prelude ~= nil and prelude[pi] ~= nil do
    table.insert(lines, "          \"" .. prelude[pi] .. "\"")
    pi = pi + 1
  end
  -- In the single-root/`built` model the root builds into `built` (the function
  -- copies built/install.zip). In mergedprefix mode there is no `built`: every
  -- package builds into a p<i> dir and the function merges them all.
  local built_root = nil
  if mergedprefix == nil then built_root = root or roots[1] end
  local oi = 1
  while emit[oi] ~= nil do
    local name = emit[oi]
    local dir = "p" .. H.numstr(oi - 1)
    if built_root ~= nil and name == built_root then dir = "built" end
    local rf = "          \"run-function " .. rulefn .. " -d " .. dir
      .. " modver=" .. pkgpath .. ".Pkg." .. H.modsegment(name) .. "@" .. version
      .. " pkg=" .. name
      .. " localsrc=" .. localsrc
      .. " locksrcpath=" .. locksrcpath
      -- Plumb the target ABI so the per-package rule selects the target DkML
      -- toolchain (not the host's) on a cross build. `Release.target_abi` resolves
      -- to the execution abi when no --target-abi is set, so non-cross slots are
      -- unchanged. The rule defaults to this same wildcard, so drivers generated
      -- before this field still cross-compile correctly.
      .. " targetabi=Release.target_abi"
      -- The OCaml compiler this lock is built with: the rule stages this toolchain,
      -- and it is the compatibility key for consuming the imported deps below.
      .. " ocaml=" .. gate_ocaml
    if parallel ~= nil then
      -- Direct build edges: pass each in-closure direct dependency so the rule's
      -- declareinput turns them into input_objects (the true DAG). Imported deps are
      -- not emitted Pkg objects, so inorder[] excludes them; they stage via impdep_.
      local e = byname[name]
      local ei = 1
      while e ~= nil and e.depends ~= nil and e.depends[ei] ~= nil do
        local d = e.depends[ei]
        if inorder[d] ~= nil and d ~= name then rf = rf .. " deps[]=" .. d end
        ei = ei + 1
      end
    end
    -- Import staging: for every imported package in THIS package's closure, hand the
    -- rule the foreign object id (impdep_<Seg>=<id>) so it stages the prebuilt object
    -- instead of building a local sibling. The rule stages only its own closure, so
    -- ids for packages outside it are never looked up.
    local iseen = {}
    local iord = {}
    H.driver_visit(byname, provided, name, iseen, iord)
    local ij = 1
    while iord[ij] ~= nil do
      local dn = iord[ij]
      if imported[dn] ~= nil then rf = rf .. " impdep_" .. H.modsegment(dn) .. "=" .. imported[dn] end
      ij = ij + 1
    end
    table.insert(lines, rf .. "\"")
    oi = oi + 1
  end
  local li = 1
  while lines[li] ~= nil do
    body = body .. lines[li]
    if lines[li + 1] ~= nil then body = body .. "," end
    body = body .. nl
    li = li + 1
  end
  local slotlist = ""
  local si = 1
  while slots[si] ~= nil do
    if si > 1 then slotlist = slotlist .. ", " end
    slotlist = slotlist .. "\"" .. slots[si] .. "\""
    si = si + 1
  end
  -- Function + outputs. Default (single root): copy built/install.zip out as
  -- install.zip. mergedprefix: extract every built package's install.zip into
  -- one prefix p/ (mirrors F_BuildLockedPackage's dep staging), seed the seq
  -- META stub, and zip p/ as prefix.zip -- the whole external dependency prefix
  -- in one object for a consumer to stage on OCAMLPATH.
  local co = "\"$(get-object CommonsBase_Std.Coreutils@0.8.0 -s ${SLOTNAME.Release.execution_abi} -m ./coreutils.exe -f coreutils.exe -e '*')\""
  local outname = "install.zip"
  local fcmds = {}
  if mergedprefix ~= nil then
    outname = "prefix.zip"
    local zz = "\"$(get-object CommonsBase_Std.S7z@25.1.0 -s Release.execution_abi -e '*' -d :)/7zz.exe\""
    local sq = "\"$(get-asset CommonsLang_OCaml.Apparatus.OpamBuildSeqMeta@1.0.1 -p assets/opam/seq-META -f seq-meta-src)\""
    table.insert(fcmds, "          [" .. nl .. "            " .. co .. ", \"mkdir\", \"-p\", \"p/lib/seq\"" .. nl .. "          ]")
    table.insert(fcmds, "          [" .. nl .. "            " .. co .. ", \"cp\", " .. sq .. ", \"p/lib/seq/META\"" .. nl .. "          ]")
    local pj = 1
    while emit[pj] ~= nil do
      table.insert(fcmds, "          [" .. nl .. "            " .. zz .. ", \"x\", \"-y\", \"-op\", \"p" .. H.numstr(pj - 1) .. "/install.zip\"" .. nl .. "          ]")
      pj = pj + 1
    end
    -- Imported packages are not built here, so they produce no p<i>/install.zip;
    -- fetch each one's prebuilt install.zip and extract it into the same merged p/
    -- prefix, so prefix.zip carries the whole closure (imported + locally built).
    local qj = 1
    while order[qj] ~= nil do
      local qn = order[qj]
      if imported[qn] ~= nil then
        table.insert(fcmds, "          [" .. nl .. "            " .. zz .. ", \"x\", \"-y\", \"-op\", \"$(get-object " .. imported[qn] .. " -s ${SLOTNAME.request} -m ./install.zip -f imp-" .. H.numstr(qj) .. ".zip)\"" .. nl .. "          ]")
      end
      qj = qj + 1
    end
    table.insert(fcmds, "          [" .. nl .. "            " .. zz .. ", \"a\", \"-tzip\", \"${SLOT.request}/prefix.zip\", \"./p/*\"" .. nl .. "          ]")
  else
    table.insert(fcmds, "          [" .. nl .. "            " .. co .. "," .. nl .. "            \"cp\", \"built/install.zip\", \"${SLOT.request}/install.zip\"" .. nl .. "          ]")
  end
  local fnjoined = ""
  local fj = 1
  while fcmds[fj] ~= nil do
    fnjoined = fnjoined .. fcmds[fj]
    if fcmds[fj + 1] ~= nil then fnjoined = fnjoined .. "," end
    fnjoined = fnjoined .. nl
    fj = fj + 1
  end
  body = body
    .. "        ]" .. nl
    .. "      }," .. nl
    .. "      \"function\": {" .. nl
    .. "        \"commands\": [" .. nl
    .. fnjoined
    .. "        ]" .. nl
    .. "      }," .. nl
    .. "      \"outputs\": { \"assets\": [ { \"slots\": [" .. slotlist .. "], \"paths\": [\"" .. outname .. "\"] } ] }" .. nl
    .. "    }" .. nl
    .. "  ]" .. nl
    .. "}" .. nl

  local meta = request.ui.checksum { path = out }
  local expected = "false"
  if meta and meta.sha256 then expected = meta.sha256 end
  local ok, written = request.ui.writefile { path = out, content = body, expected_sha256 = expected }
  assert(ok, "could not write driver to `" .. out .. "`: " .. tostring(written))
  print("wrote driver (" .. H.numstr(oi - 1) .. " packages) to " .. tostring(written))
  return { submit = {} }
end

return M
