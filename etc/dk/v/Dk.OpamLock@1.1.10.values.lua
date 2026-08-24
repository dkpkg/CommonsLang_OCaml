local M = {
  id = "CommonsLang_OCaml.Dk.OpamLock@1.1.10"
}

-- 1.1.10 adds the OpamVenv uirule: a developer-facing dialog that materializes
-- a real, dune-usable opam prefix from the already-built dependency closure so
-- `dune build -w` runs natively against the working tree, instead of dk's
-- per-edit whole-package rebuild. It reuses a GenerateDriver `mergedprefix=t
-- skiplocal=t` driver (the non-local closure merged into one cached prefix.zip
-- object), stages that prefix plus the DkML compiler and Dune into `opam-venv/`,
-- rewrites the staged prefix to be relocatable (the @OPAM_IP@ dune-package
-- sentinel and findlib.conf), and writes env.sh/.ps1/.cmd activators plus a
-- lock-sha256 stamp for idempotent refresh. See dk.u "## Dk.OpamLock".
-- 1.1.10 also fixes Refresh on a lockless (consume-from-archive) driver: it now
-- re-stamps the GenerateDriver tool version, not only the F_BuildLockedPackage
-- rulefn, so a pure tool-version bump (a scriptmodule rename that mode=check
-- flags) is cleared by the Refresh command the check prints instead of staying
-- permanently stale.
--
-- 1.1.9 rides the --wdoc content edit to assets/opam-lock/dk_opam_lock.ml on an
-- Apparatus bump (OpamLockHelper@1.0.14 -> @1.0.15). Solve passes --with-doc to
-- the opam solve when wdoc is set and stamps wdoc into the lock generated block,
-- so a with-doc lock carries odoc. The keep-latest-only policy (dk.u "## Assets")
-- requires the asset bump: editing the helper bytes in place at the same version
-- serves stale bytes to a warm store (the v5-ppxlib mechanism).
--
-- 1.1.8 makes the two generated artifacts self-describing and adds the Refresh
-- uirule. Solve now stamps its `roots`/`pins` (and `wtest`/`wdoc`/`local_opam_dir`
-- when set) into the lock's `generated` block, and GenerateDriver stamps its full
-- parameter set into a top-level `generated` member of the driver values.jsonc
-- (right after `schema_version`). MlFront's value reader pulls members by name
-- and ignores unknown top-level members, so no dk-value schema change is needed.
-- Refresh reads those stamps back to regenerate a driver (default), re-solve the
-- lock then regenerate (mode=solve), or check a driver against the imported rule
-- versions and exit nonzero when stale (mode=check). A stampless (pre-1.1.8)
-- driver is adopted on first Refresh by recovering its parameters from the
-- generated text. See dk.u "## Dk.OpamLock".
--
-- 1.1.7 flips the default host-tool ABI. Through 1.1.6 GenerateDriver pinned
-- ocamlfind/ocamlbuild to `Release.execution_abi`; that pin never shipped in
-- any consumed driver, and a cross slot that CAN emulate its target (Windows_x86
-- under WOW64, Darwin_x86_64 under Rosetta, Linux_x86 under multilib) needs the
-- host tool's findlib metadata to match the TARGET, so 1.1.7 defaults host tools
-- to `targetabi=Release.target_abi` (the dual-role convention, SPECIFICATION
-- "Object Slot ABI"; validated fix ocamlearlybird 57fd802). The new
-- `hosttoolabi=` GenerateDriver parameter restores `Release.execution_abi` for a
-- matrix containing a cross slot the host CANNOT emulate (e.g. a glibc host
-- targeting Linux_x86_64_musl -- the musl hazard the 1.1.4 pin guarded).
--
-- 1.1.6 is behaviorally identical to 1.1.5; it exists because the helper
-- assets were collapsed onto stable file names (Apparatus.OpamLockHelper@1.0.10
-- at assets/opam-lock/dk_opam_lock.ml) when the old per-version file variants
-- were retired. See dk.u "## Assets" for the policy.
--
-- 1.1.5 dropped the dependencies opam gates behind with-test, with-doc or
-- with-dev-setup from each package's `depends`. Through 1.1.4 the lock recorded
-- them as build edges, which made the graph CYCLIC -- re depends on ppx_expect
-- only to run its tests while ppx_expect really depends on re -- and a cycle
-- has no build order, so a consuming build could not finish. The filtering
-- lives in the OCaml helper, which is where `depends` is computed.

-- lua-ml does not support local functions, and a "local" variable would be nil
-- inside the rules/uirules function bodies. So a should-be-unique global table
-- holds the helpers, matching the house style in CommonsBase_Std.Extract and
-- CommonsBase_Remote.GitHub.
CommonsLang_OCaml__Dk_OpamLock__1_1_10 = {}

rules, uirules = build.newrules(M)

-- lua-ml's string library does not implement gsub, so trim by scanning for the
-- first/last non-space with find (which does support patterns).
function CommonsLang_OCaml__Dk_OpamLock__1_1_10.iswhite(c)
  local b = string.byte(c)
  return b == 32 or b == 9 or b == 13 or b == 10
end

-- Explicit whitespace checks (space/tab/CR/LF by byte value: raw control
-- bytes and \r are unrepresentable in lua-ml string literals): lua-ml's %s
-- class does not match CR, which left a trailing CR on every line of CRLF
-- opam output on Windows (ex. the
-- switch-exists check compared name-plus-CR ~= name and re-created the
-- switch).
function CommonsLang_OCaml__Dk_OpamLock__1_1_10.trim(s)
  if s == nil then return "" end
  local n = string.len(s)
  local a = 1
  while a <= n and CommonsLang_OCaml__Dk_OpamLock__1_1_10.iswhite(string.sub(s, a, a)) do a = a + 1 end
  if a > n then return "" end
  local b = n
  while b >= 1 and CommonsLang_OCaml__Dk_OpamLock__1_1_10.iswhite(string.sub(s, b, b)) do b = b - 1 end
  return string.sub(s, a, b)
end

-- Join an ARRAY's elements in index order. Iterating with next() (as an earlier
-- version did) walks lua-ml's arbitrary hash order, which silently scrambled the
-- order of every joined array -- including the JSON encoder's `parts`, so a
-- sorted key list still emitted unsorted. Walk 1..n instead.
function CommonsLang_OCaml__Dk_OpamLock__1_1_10.join(tbl, sep)
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

function CommonsLang_OCaml__Dk_OpamLock__1_1_10.set_from_list(tbl)
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
function CommonsLang_OCaml__Dk_OpamLock__1_1_10.dirname(p)
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
          id = "CommonsLang_OCaml.Dk.OpamLock.Export@1.1.10",
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
  local H = CommonsLang_OCaml__Dk_OpamLock__1_1_10
  if command == "ui" then
    print("CommonsLang_OCaml.Dk.OpamLock@1.1.10: lock written.")
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
      helper = "$(get-asset CommonsLang_OCaml.Apparatus.OpamLockHelper@1.0.15 -p assets/opam-lock/dk_opam_lock.ml -f dk_opam_lock.ml)",
      amalgam = "$(get-asset CommonsLang_OCaml.Apparatus.OpamFileFormat@1.0.1 -p assets/opam-lock/opam_file_format.ml -f opam_file_format.ml)"
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
    "--pins-name", pinsproj,
    "--tool", "CommonsLang_OCaml.Dk.OpamLock@1.1.10" }
  local out = request.user.out or "dk.opam-lock.jsonc"
  if request.user.switch then table.insert(args, "--switch"); table.insert(args, request.user.switch) end
  if request.user.local_opam_dir then table.insert(args, "--local-opam-dir"); table.insert(args, request.user.local_opam_dir) end
  if request.user.wtest ~= nil then table.insert(args, "--wtest") end
  if request.user.wdoc ~= nil then table.insert(args, "--wdoc") end
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
function CommonsLang_OCaml__Dk_OpamLock__1_1_10.indexof_char(s, ch)
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
function CommonsLang_OCaml__Dk_OpamLock__1_1_10.numstr(v)
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
function CommonsLang_OCaml__Dk_OpamLock__1_1_10.modsegment(name)
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

-- Host tools: opam packages whose built artifacts are native executables RUN on
-- the build host during later package builds (topkg's `ocaml pkg/pkg.ml build`
-- invokes `ocamlfind`/`ocamlbuild`). They are dual-role: the build must RUN them,
-- and their findlib metadata (stdlib path, ocamlmklib/ocamlc config, arch flags)
-- flows into every later package build. On a cross slot whose host can EMULATE
-- the target (WOW64 / Rosetta / multilib), building them at `target_abi` keeps
-- that metadata matching the target and still lets them run -- the default. When
-- the host CANNOT emulate the target (a glibc host targeting Linux_x86_64_musl),
-- a target-ABI host tool is a host-unrunnable binary, and because the opam-build
-- form is host-keyed with the `target_abi` WILDCARD in its value-id, that one
-- musl build is store-shared to every slot; there `hosttoolabi=Release.execution_abi`
-- pins them back to the host. GenerateDriver emits `hosttoolabi` for these names.
function CommonsLang_OCaml__Dk_OpamLock__1_1_10.is_host_tool(name)
  return name == "ocamlfind" or name == "ocamlbuild"
end

-- Packages provided by the DkML toolchain objects or purely virtual: never
-- built as Pkg objects, so the driver never chains them. The default for
-- GenerateDriver's provided[] parameter; a project on another toolchain
-- passes its own list. Mirrors PROVIDED in CommonsBase_Dk.Dk0Build.
CommonsLang_OCaml__Dk_OpamLock__1_1_10.DKML_PROVIDED = {
  "ocaml", "ocaml-base-compiler", "ocaml-config", "ocaml-options-vanilla",
  "base-unix", "base-threads", "base-bigarray", "dune", "flexdll",
  "conf-mingw-w64-gcc-x86_64", "host-arch-x86_64", "host-arch-x86_32",
  "host-arch-arm64", "host-system-mingw", "host-system-other"
}

-- The 8 DkML slots; the default for GenerateDriver's slots[] parameter.
CommonsLang_OCaml__Dk_OpamLock__1_1_10.DKML_SLOTS = {
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
function CommonsLang_OCaml__Dk_OpamLock__1_1_10.driver_visit(byname, provided, name, seen, order)
  local H = CommonsLang_OCaml__Dk_OpamLock__1_1_10
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
-- Parameters (dk0 dialog CommonsLang_OCaml.Dk.OpamLock.GenerateDriver@1.1.10):
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
--   'hosttoolabi=SLOT' optional: the ABI for ocamlfind/ocamlbuild (default:
--                      Release.target_abi). Pass Release.execution_abi for a
--                      matrix with a host-unemulatable cross slot (musl hazard).
function uirules.GenerateDriver(command, request)
  local H = CommonsLang_OCaml__Dk_OpamLock__1_1_10
  if command == "ui" then
    print("CommonsLang_OCaml.Dk.OpamLock@1.1.10: driver written.")
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

  -- Host-tool ABI (hosttoolabi=SLOT): the ABI for ocamlfind/ocamlbuild. Defaults
  -- to the target ABI (dual-role convention); pass Release.execution_abi for a
  -- matrix with a cross slot the host cannot emulate (the musl hazard).
  local hosttoolabi = request.user.hosttoolabi
  if hosttoolabi == nil then hosttoolabi = "Release.target_abi" end

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

  -- Stamp the full parameter set into a top-level `generated` member so Refresh
  -- (and mode=check) can regenerate or validate this driver without re-deriving
  -- the ~ten hand-copied parameters. Only out= is omitted (it is this file's own
  -- path). MlFront's value reader pulls members by name and ignores unknown
  -- top-level members, so this needs no dk-value schema change. Values here are
  -- module ids and project-relative paths (no quote/backslash bytes), so they
  -- are concatenated without JSON escaping, like the rest of this header.
  local lockmeta = request.ui.checksum { path = lockpath }
  local locksha = ""
  if lockmeta and lockmeta.sha256 then locksha = lockmeta.sha256 end
  local gm = {}
  table.insert(gm, "\"tool\": \"CommonsLang_OCaml.Dk.OpamLock.GenerateDriver@1.1.10\"")
  table.insert(gm, "\"rulefn\": \"" .. rulefn .. "\"")
  table.insert(gm, "\"lock\": \"" .. lockpath .. "\"")
  table.insert(gm, "\"lock-sha256\": \"" .. locksha .. "\"")
  table.insert(gm, "\"localsrc\": \"" .. localsrc .. "\"")
  table.insert(gm, "\"locksrcpath\": \"" .. locksrcpath .. "\"")
  if root ~= nil then
    table.insert(gm, "\"root\": \"" .. root .. "\"")
  else
    table.insert(gm, "\"roots\": [\"" .. H.join(roots, "\", \"") .. "\"]")
  end
  table.insert(gm, "\"formid\": \"" .. formid .. "\"")
  table.insert(gm, "\"pkgpath\": \"" .. pkgpath .. "\"")
  table.insert(gm, "\"version\": \"" .. version .. "\"")
  if request.user.skiplocal ~= nil then table.insert(gm, "\"skiplocal\": \"t\"") end
  if request.user.mergedprefix ~= nil then table.insert(gm, "\"mergedprefix\": \"t\"") end
  if request.user.parallel ~= nil then table.insert(gm, "\"parallel\": \"t\"") end
  if request.user.hosttoolabi ~= nil then table.insert(gm, "\"hosttoolabi\": \"" .. request.user.hosttoolabi .. "\"") end
  if request.user.prelude ~= nil then table.insert(gm, "\"prelude\": [\"" .. H.join(request.user.prelude, "\", \"") .. "\"]") end
  if request.user.provided ~= nil then table.insert(gm, "\"provided\": [\"" .. H.join(request.user.provided, "\", \"") .. "\"]") end
  if request.user.slots ~= nil then table.insert(gm, "\"slots\": [\"" .. H.join(request.user.slots, "\", \"") .. "\"]") end
  if request.user.implib ~= nil then table.insert(gm, "\"implib\": [\"" .. H.join(request.user.implib, "\", \"") .. "\"]") end
  if request.user.impver ~= nil then table.insert(gm, "\"impver\": [\"" .. H.join(request.user.impver, "\", \"") .. "\"]") end
  if request.user.impsrclock ~= nil then table.insert(gm, "\"impsrclock\": [\"" .. H.join(request.user.impsrclock, "\", \"") .. "\"]") end
  local genblock = "  \"generated\": {" .. nl .. "    " .. H.join(gm, "," .. nl .. "    ") .. nl .. "  }," .. nl

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
    .. genblock
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
      --
      -- Host tools (`ocamlfind`/`ocamlbuild`) default to `target_abi` too so a
      -- cross slot the host can emulate gets target-matching findlib metadata (see
      -- is_host_tool). `hosttoolabi=Release.execution_abi` overrides them back to
      -- the host for a matrix with a host-unemulatable cross slot (the musl
      -- hazard); see dk.u "## Host tools and the hosttoolabi= escape hatch".
      .. " targetabi=" .. (H.is_host_tool(name) and hosttoolabi or "Release.target_abi")
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

-- ---------------------------------------------------------------------------
-- Refresh: self-describing regeneration of the lock and driver(s).
--
-- The lock and driver stamp their inputs (Solve stamps roots/pins into the
-- lock's `generated` block; GenerateDriver stamps its full parameter set into
-- the driver's top-level `generated` member). Refresh reads those stamps back
-- so a routine repin regenerates with a one-liner and CI can detect a stale
-- driver in seconds instead of hours into a release build.
-- ---------------------------------------------------------------------------

-- Byte-scan substring search (string.find treats `.`/`-` as pattern magic, so
-- module ids and version strings must be searched literally). Returns the
-- 1-based index of `sub` in `s` at or after `from`, or nil.
function CommonsLang_OCaml__Dk_OpamLock__1_1_10.indexof_str(s, sub, from)
  local n = string.len(s)
  local m = string.len(sub)
  if m == 0 then if from == nil then return 1 else return from end end
  local i = from
  if i == nil then i = 1 end
  while i + m - 1 <= n do
    if string.sub(s, i, i + m - 1) == sub then return i end
    i = i + 1
  end
  return nil
end

-- Replace every literal occurrence of `old` with `new` (lua-ml has no gsub).
function CommonsLang_OCaml__Dk_OpamLock__1_1_10.replace_all(s, old, new)
  local H = CommonsLang_OCaml__Dk_OpamLock__1_1_10
  if old == "" then return s end
  local out = ""
  local i = 1
  local m = string.len(old)
  local p = H.indexof_str(s, old, 1)
  while p ~= nil do
    out = out .. string.sub(s, i, p - 1) .. new
    i = p + m
    p = H.indexof_str(s, old, i)
  end
  return out .. string.sub(s, i, string.len(s))
end

-- Number of leading decimal digits of `s` as an integer (stops at the first
-- non-digit, so "1.0.18" component "18" -> 18, "2-26" -> 2).
function CommonsLang_OCaml__Dk_OpamLock__1_1_10.toint(s)
  local n = 0
  local i = 1
  local len = string.len(s)
  while i <= len do
    local b = string.byte(s, i)
    if b >= 48 and b <= 57 then n = n * 10 + (b - 48); i = i + 1 else i = len + 1 end
  end
  return n
end

-- Substring after the last '@' of a module id (its version), or the whole id.
function CommonsLang_OCaml__Dk_OpamLock__1_1_10.id_ver(id)
  local i = string.len(id)
  while i >= 1 do
    if string.sub(id, i, i) == "@" then return string.sub(id, i + 1) end
    i = i - 1
  end
  return id
end

-- Split a dotted version into numeric components (numeric while, not next()).
function CommonsLang_OCaml__Dk_OpamLock__1_1_10.vparts(ver)
  local H = CommonsLang_OCaml__Dk_OpamLock__1_1_10
  local parts = {}
  local cur = ""
  local i = 1
  local n = string.len(ver)
  while i <= n do
    local c = string.sub(ver, i, i)
    if c == "." then table.insert(parts, H.toint(cur)); cur = "" else cur = cur .. c end
    i = i + 1
  end
  table.insert(parts, H.toint(cur))
  return parts
end

-- Compare two dotted versions: 1 if a>b, -1 if a<b, 0 if equal.
function CommonsLang_OCaml__Dk_OpamLock__1_1_10.vcmp(a, b)
  local H = CommonsLang_OCaml__Dk_OpamLock__1_1_10
  local pa = H.vparts(a)
  local pb = H.vparts(b)
  local i = 1
  while pa[i] ~= nil or pb[i] ~= nil do
    local x = pa[i]; if x == nil then x = 0 end
    local y = pb[i]; if y == nil then y = 0 end
    if x > y then return 1 end
    if x < y then return -1 end
    i = i + 1
  end
  return 0
end

-- Highest-versioned id in `text` whose form is `<prefix>@<ver>`. The import
-- values.json can declare several versions of one rule side by side, so this is
-- a semver max over every occurrence, not "the one entry". nil if none.
function CommonsLang_OCaml__Dk_OpamLock__1_1_10.import_max(text, prefix)
  local H = CommonsLang_OCaml__Dk_OpamLock__1_1_10
  local needle = prefix .. "@"
  local m = string.len(needle)
  local n = string.len(text)
  local best = nil
  local p = H.indexof_str(text, needle, 1)
  while p ~= nil do
    local vstart = p + m
    local q = vstart
    while q <= n and string.sub(text, q, q) ~= "\"" do q = q + 1 end
    local ver = string.sub(text, vstart, q - 1)
    if best == nil or H.vcmp(ver, best) > 0 then best = ver end
    p = H.indexof_str(text, needle, q)
  end
  if best == nil then return nil end
  return prefix .. "@" .. best
end

-- The CommonsLang_OCaml import version pinned in dk.u, or nil.
function CommonsLang_OCaml__Dk_OpamLock__1_1_10.dku_import_version(text)
  local H = CommonsLang_OCaml__Dk_OpamLock__1_1_10
  local lib = H.indexof_str(text, "library: \"CommonsLang_OCaml\"", 1)
  if lib == nil then return nil end
  local key = "version: \""
  local vk = H.indexof_str(text, key, lib)
  if vk == nil then return nil end
  local vstart = vk + string.len(key)
  local n = string.len(text)
  local q = vstart
  while q <= n and string.sub(text, q, q) ~= "\"" do q = q + 1 end
  return string.sub(text, vstart, q - 1)
end

-- Read the imported rule versions this workspace declares: { ver, rulefn, tool }
-- from dk.u's pin + etc/dk/i/CommonsLang_OCaml.<ver>.values.json. nil when there
-- is no import; rulefn/tool nil when the import file is absent.
function CommonsLang_OCaml__Dk_OpamLock__1_1_10.import_wants(request)
  local H = CommonsLang_OCaml__Dk_OpamLock__1_1_10
  local dku = request.ui.readfile { path = "dk.u" }
  if dku == nil then return nil end
  local V = H.dku_import_version(dku)
  if V == nil then return nil end
  local imp = request.ui.readfile { path = "etc/dk/i/CommonsLang_OCaml." .. V .. ".values.json" }
  if imp == nil then return { ver = V } end
  return {
    ver = V,
    rulefn = H.import_max(imp, "CommonsLang_OCaml.Dk.OpamBuild.F_BuildLockedPackage"),
    tool = H.import_max(imp, "CommonsLang_OCaml.Dk.OpamLock.GenerateDriver")
  }
end

-- The decoded top-level `generated` stamp of a driver values.jsonc, or nil for
-- a pre-@1.1.8 (unstamped) driver. Strips the `//` banner (which precedes the
-- first `{`) before decoding; the JSON body itself has no comments.
function CommonsLang_OCaml__Dk_OpamLock__1_1_10.read_stamp(drivertext)
  local H = CommonsLang_OCaml__Dk_OpamLock__1_1_10
  local b = H.indexof_str(drivertext, "{", 1)
  if b == nil then return nil end
  local jd = require("jsondk")
  local obj = jd.decode(string.sub(drivertext, b))
  if obj == nil then return nil end
  return obj.generated
end

-- The full F_BuildLockedPackage id used in a driver's text (for an unstamped
-- driver: the rulefn is still recoverable even though the stamp is not).
function CommonsLang_OCaml__Dk_OpamLock__1_1_10.first_rulefn(text)
  local H = CommonsLang_OCaml__Dk_OpamLock__1_1_10
  local key = "CommonsLang_OCaml.Dk.OpamBuild.F_BuildLockedPackage@"
  local p = H.indexof_str(text, key, 1)
  if p == nil then return nil end
  local n = string.len(text)
  local q = p
  while q <= n do
    local c = string.sub(text, q, q)
    if c == " " or c == "\"" then return string.sub(text, p, q - 1) end
    q = q + 1
  end
  return string.sub(text, p, n)
end

-- Length of a 1-based array (numeric while; next() is unordered).
function CommonsLang_OCaml__Dk_OpamLock__1_1_10.alen(t)
  local i = 0
  while t[i + 1] ~= nil do i = i + 1 end
  return i
end

-- The value of the `key=` token in a driver precommand line (up to the next
-- space or quote), or nil.
function CommonsLang_OCaml__Dk_OpamLock__1_1_10.kv(line, key)
  local H = CommonsLang_OCaml__Dk_OpamLock__1_1_10
  local p = H.indexof_str(line, key, 1)
  if p == nil then return nil end
  local s = p + string.len(key)
  local n = string.len(line)
  local q = s
  while q <= n do
    local c = string.sub(line, q, q)
    if c == " " or c == "\"" then return string.sub(line, s, q - 1) end
    q = q + 1
  end
  return string.sub(line, s, n)
end

-- ocamlfind/ocamlbuild host-tool ABI recovered from the precommand lines, when
-- it differs from the default Release.target_abi; else nil.
function CommonsLang_OCaml__Dk_OpamLock__1_1_10.recover_hosttoolabi(privlist)
  local H = CommonsLang_OCaml__Dk_OpamLock__1_1_10
  local i = 1
  while privlist[i] ~= nil do
    local ln = privlist[i]
    if H.indexof_str(ln, "pkg=ocamlfind") ~= nil or H.indexof_str(ln, "pkg=ocamlbuild") ~= nil then
      local ta = H.kv(ln, "targetabi=")
      if ta ~= nil and ta ~= "Release.target_abi" then return ta end
    end
    i = i + 1
  end
  return nil
end

-- The set of `pkg=<name>` tokens in a driver's text (multiset membership as a
-- name->"1" map). Used to verify a stampless regen reproduced the same closure.
function CommonsLang_OCaml__Dk_OpamLock__1_1_10.pkgset(text)
  local H = CommonsLang_OCaml__Dk_OpamLock__1_1_10
  local set = {}
  local n = string.len(text)
  local p = H.indexof_str(text, "pkg=", 1)
  while p ~= nil do
    local s = p + 4
    local q = s
    while q <= n and string.sub(text, q, q) ~= " " and string.sub(text, q, q) ~= "\"" do q = q + 1 end
    set[string.sub(text, s, q - 1)] = "1"
    p = H.indexof_str(text, "pkg=", q)
  end
  return set
end

function CommonsLang_OCaml__Dk_OpamLock__1_1_10.same_set(a, b)
  local k = next(a)
  while k do if b[k] == nil then return nil end; k = next(a, k) end
  k = next(b)
  while k do if a[k] == nil then return nil end; k = next(b, k) end
  return 1
end

-- Replace the version after the last '@' of a module id.
function CommonsLang_OCaml__Dk_OpamLock__1_1_10.reversion(id, newver)
  local i = string.len(id)
  while i >= 1 do
    if string.sub(id, i, i) == "@" then return string.sub(id, 1, i) .. newver end
    i = i - 1
  end
  return id .. "@" .. newver
end

-- Split a string on newline, dropping CR (byte 13, unrepresentable as a literal).
function CommonsLang_OCaml__Dk_OpamLock__1_1_10.splitlines(s)
  local lines = {}
  local cur = ""
  local i = 1
  local n = string.len(s)
  while i <= n do
    local c = string.sub(s, i, i)
    if c == "\n" then
      table.insert(lines, cur); cur = ""
    else
      if string.byte(c) ~= 13 then cur = cur .. c end
    end
    i = i + 1
  end
  table.insert(lines, cur)
  return lines
end

function CommonsLang_OCaml__Dk_OpamLock__1_1_10.ends_with(s, suf)
  local ls = string.len(s)
  local lf = string.len(suf)
  if lf > ls then return nil end
  if string.sub(s, ls - lf + 1, ls) == suf then return 1 end
  return nil
end

-- Recover GenerateDriver parameters from a stampless (pre-@1.1.8) driver so its
-- first Refresh can adopt the stamp. Covers the single-root, non-partitioned
-- shape (ocamlearlybird); a richer driver (skiplocal/import-partition) predates
-- this only in CommonsBase_Dk, which adopts by hand-inserting a full stamp.
function CommonsLang_OCaml__Dk_OpamLock__1_1_10.fallback_params(text)
  local H = CommonsLang_OCaml__Dk_OpamLock__1_1_10
  local b = H.indexof_str(text, "{", 1)
  assert(b ~= nil, "driver has no JSON body")
  local jd = require("jsondk")
  local obj = jd.decode(string.sub(text, b))
  assert(obj ~= nil and obj.forms ~= nil and obj.forms[1] ~= nil, "driver has no forms")
  local f = obj.forms[1]
  local pc = f.precommands
  assert(pc ~= nil and pc["private"] ~= nil, "driver has no precommands")
  local priv = pc["private"]
  local li = 1
  while priv[li] ~= nil and H.indexof_str(priv[li], "modver=") == nil do li = li + 1 end
  assert(priv[li] ~= nil, "driver has no per-package build line")
  local line = priv[li]
  local P = {}
  P.formid = f.id
  P.localsrc = H.kv(line, "localsrc=")
  P.locksrcpath = H.kv(line, "locksrcpath=")
  local modver = H.kv(line, "modver=")
  assert(modver ~= nil, "cannot recover modver from the driver")
  P.version = H.id_ver(modver)
  local pk = H.indexof_str(modver, ".Pkg.")
  assert(pk ~= nil, "cannot recover pkgpath from modver `" .. modver .. "`")
  P.pkgpath = string.sub(modver, 1, pk - 1)
  if H.indexof_str(text, "\"sequential\": false") ~= nil then P.parallel = "t" end
  if f.outputs ~= nil and f.outputs.assets ~= nil and f.outputs.assets[1] ~= nil then
    P.slots = f.outputs.assets[1].slots
    local paths = f.outputs.assets[1].paths
    if paths ~= nil and paths[1] == "prefix.zip" then P.mergedprefix = "t" end
  end
  -- Root: in the single-root model the root builds into `-d built`; read its
  -- pkg= (mergedprefix drivers have no `built` line and are adopted by hand, so
  -- fallback recovery does not need to cover them).
  local bi = 1
  while priv[bi] ~= nil and H.indexof_str(priv[bi], "-d built ") == nil do bi = bi + 1 end
  if priv[bi] ~= nil then
    local rp = H.kv(priv[bi], "pkg=")
    if rp ~= nil then P.root = rp end
  end
  local hta = H.recover_hosttoolabi(priv)
  if hta ~= nil then P.hosttoolabi = hta end
  return P
end

-- Standard STALE message with the actionable fix command.
function CommonsLang_OCaml__Dk_OpamLock__1_1_10.stale_msg(D, got, want)
  return "STALE " .. D .. ":" .. "\n  driver pins  " .. tostring(got)
    .. "\n  import wants " .. tostring(want)
    .. "\n  fix: ./dk1 dialog CommonsLang_OCaml.Dk.OpamLock.Refresh@1.1.10 driver=" .. D
    .. "\n       (dk0 and dkjs take the same arguments)"
end

-- Discover the generated OpamLock driver(s) under etc/dk/v by running a
-- hermetic coreutils `ls -R` (there is no directory-listing ui API) and keeping
-- every *.values.jsonc whose banner names GenerateDriver.
function CommonsLang_OCaml__Dk_OpamLock__1_1_10.discover_drivers(request, coreutils)
  local H = CommonsLang_OCaml__Dk_OpamLock__1_1_10
  local res = request.ui.capture {
    program = coreutils, args = { "ls", "-R", "etc/dk/v" }, max_output_bytes = 4194304
  }
  assert(res and res.status == "exit" and res.code == 0,
    "could not list etc/dk/v: " .. tostring(res and res.stderr))
  local out = {}
  local cur = "etc/dk/v"
  local lines = H.splitlines(res.stdout)
  local i = 1
  while lines[i] ~= nil do
    local ln = H.trim(lines[i])
    if ln ~= "" then
      local last = string.sub(ln, string.len(ln), string.len(ln))
      if last == ":" then
        cur = string.sub(ln, 1, string.len(ln) - 1)
      else
        if H.ends_with(ln, ".values.jsonc") ~= nil then
          local path = cur .. "/" .. ln
          local content = request.ui.readfile { path = path }
          if content ~= nil
             and H.indexof_str(content, "GENERATED by the CommonsLang_OCaml.Dk.OpamLock.GenerateDriver") ~= nil then
            table.insert(out, path)
          end
        end
      end
    end
    i = i + 1
  end
  return out
end

-- Build the Solve dialog user parameters for mode=solve by reading the lock's
-- own `generated` stamp (roots/pins/wtest/local_opam_dir), its `ocaml`, its
-- slots, and the bare names of its "local":"t" packages.
function CommonsLang_OCaml__Dk_OpamLock__1_1_10.solve_user(request)
  local H = CommonsLang_OCaml__Dk_OpamLock__1_1_10
  local lockpath = request.user.lock or "dk.opam-lock.jsonc"
  local content = assert(request.ui.readfile { path = lockpath },
    "could not read lock `" .. lockpath .. "` for mode=solve")
  local jd = require("jsondk")
  local lock = jd.decode(content)
  assert(lock ~= nil and lock.packages ~= nil, "could not decode lock for mode=solve")
  local gen = lock.generated
  assert(gen ~= nil and gen.roots ~= nil,
    "lock predates @1.1.8 (no generated.roots); run Solve once with explicit roots/pins to adopt the stamp")
  local u = {}
  u.roots = gen.roots
  if gen.pins ~= nil then u.pins = gen.pins end
  u.out = lockpath
  if lock.ocaml ~= nil then u.ocaml = lock.ocaml end
  if gen.wtest ~= nil then u.wtest = gen.wtest end
  if gen.wdoc ~= nil then u.wdoc = gen.wdoc end
  if gen.local_opam_dir ~= nil then u.local_opam_dir = gen.local_opam_dir end
  local locals = {}
  local k = next(lock.packages)
  while k do
    local e = lock.packages[k]
    if e ~= nil and e["local"] == "t" then
      local dot = H.indexof_char(k, ".")
      if dot ~= nil then table.insert(locals, string.sub(k, 1, dot - 1)) end
    end
    k = next(lock.packages, k)
  end
  if locals[1] ~= nil then u.locals = locals end
  local sl = {}
  if lock.slots ~= nil then
    local sk = next(lock.slots)
    while sk do table.insert(sl, sk); sk = next(lock.slots, sk) end
  end
  if sl[1] ~= nil then u.slots = sl end
  return u
end

-- Regenerate (or, for a lock-less consumer, rulefn-substitute) one driver.
function CommonsLang_OCaml__Dk_OpamLock__1_1_10.refresh_one(request, D, targetrule, versionoverride, targettool)
  local H = CommonsLang_OCaml__Dk_OpamLock__1_1_10
  local text = assert(request.ui.readfile { path = D }, "could not read driver `" .. D .. "`")
  local stamp = H.read_stamp(text)
  local lockpath = nil
  if stamp ~= nil then lockpath = stamp.lock end
  if request.user.lock ~= nil then lockpath = request.user.lock end
  local lockmeta = nil
  if lockpath ~= nil then lockmeta = request.ui.checksum { path = lockpath } end
  local haslock = lockmeta ~= nil and lockmeta.sha256 ~= nil

  if versionoverride ~= nil then
    assert(stamp ~= nil,
      "version= requires a stamped driver; run Refresh once without version= to adopt the stamp first")
    assert(haslock, "version= requires the lock on disk (" .. tostring(lockpath) .. ")")
  end

  if haslock then
    local P = nil
    local oldpkgs = nil
    if stamp ~= nil then
      P = stamp
    else
      P = H.fallback_params(text)
      oldpkgs = H.pkgset(text)
    end
    P.out = D
    P.rulefn = targetrule
    P.lock = lockpath
    if versionoverride ~= nil then
      P.version = versionoverride
      P.formid = H.reversion(P.formid, versionoverride)
      P.localsrc = H.reversion(P.localsrc, versionoverride)
    end
    local proxy = {
      user = P, ui = request.ui, io = request.io,
      execution = request.execution, continued = request.continued
    }
    uirules.GenerateDriver("submit", proxy)
    if oldpkgs ~= nil then
      local newtext = request.ui.readfile { path = D }
      local newpkgs = H.pkgset(newtext)
      if H.same_set(oldpkgs, newpkgs) == nil then
        local nm = request.ui.checksum { path = D }
        local exp = "false"
        if nm ~= nil and nm.sha256 ~= nil then exp = nm.sha256 end
        request.ui.writefile { path = D, content = text, expected_sha256 = exp }
        assert(false, "driver `" .. D
          .. "` is not reproducible from recovered parameters (package set changed); "
          .. "adopt it by running GenerateDriver explicitly with the correct parameters")
      end
    end
    print("refreshed " .. D .. " (regenerated from " .. lockpath .. ")")
  else
    assert(stamp ~= nil, "driver `" .. D
      .. "` has no stamp and its lock is not on disk; adopt it by hand-inserting a "
      .. "generated stamp, or run GenerateDriver explicitly")
    local old = stamp.rulefn
    assert(old ~= nil, "stamp for `" .. D .. "` has no rulefn")
    local newtext = H.replace_all(text, old, targetrule)
    -- Also re-stamp the generator tool version. A pure GenerateDriver bump (for
    -- example a scriptmodule rename that leaves F_BuildLockedPackage unchanged)
    -- makes the rulefn substitution above a no-op, yet mode=check still flags the
    -- stale `tool`; without this the Refresh command it prints could never clear
    -- the check on a lockless (consume-from-archive) driver.
    if targettool ~= nil and stamp.tool ~= nil and stamp.tool ~= targettool then
      newtext = H.replace_all(newtext, stamp.tool, targettool)
    end
    if newtext == text then
      print("refreshed " .. D .. " (already current)")
    else
      local nm = request.ui.checksum { path = D }
      local exp = "false"
      if nm ~= nil and nm.sha256 ~= nil then exp = nm.sha256 end
      local ok, written = request.ui.writefile { path = D, content = newtext, expected_sha256 = exp }
      assert(ok, "could not write driver `" .. D .. "`: " .. tostring(written))
      print("refreshed " .. D .. " (version stamps updated in place)")
    end
  end
end

-- Modes: driver (default; regenerate driver from the lock, or substitute the
-- rulefn when the lock is not checked in), solve (re-solve the lock then
-- regenerate), check (read-only; nonzero when a driver is stale), and version=
-- (rewrite the coupled version/formid/localsrc then regenerate).
function uirules.Refresh(command, request, continue_)
  local H = CommonsLang_OCaml__Dk_OpamLock__1_1_10
  if command == "ui" then
    print("CommonsLang_OCaml.Dk.OpamLock@1.1.10: refresh complete.")
    return
  end
  if command ~= "submit" then return end

  local mode = request.user.mode or "driver"
  local drivers = request.user.drivers
  if drivers == nil and request.user.driver ~= nil then drivers = { request.user.driver } end

  local need_disco = nil
  if drivers == nil then need_disco = 1 end
  local need_solve = nil
  if mode == "solve" then need_solve = 1 end

  -- Stage 1: materialize coreutils (for zero-argument discovery) and/or the
  -- Solve toolchain (for mode=solve), then re-enter.
  if continue_ ~= "refresh2" and (need_disco ~= nil or need_solve ~= nil) then
    local dirs = {}
    local files = {}
    if need_solve ~= nil then
      local s1 = uirules.Solve("submit", { user = {}, execution = request.execution }, nil)
      dirs = s1.submit.expressions.directories
      files = s1.submit.expressions.files
    end
    if need_disco ~= nil then
      dirs.disco = "$(get-object CommonsBase_Std.Coreutils@0.8.0 -s Release.execution_abi -d : -e 'coreutils.exe')"
    end
    local expr = { directories = dirs }
    if next(files) ~= nil then expr.files = files end
    return { submit = { expressions = expr, andthen = { continue_ = { state = "refresh2" } } } }
  end

  -- Resolve the discovery object (if materialized) and list the drivers.
  local coreutils = nil
  if request.continued ~= nil and request.continued.disco ~= nil then
    coreutils = H.trim(request.io.realpath(request.continued.disco)) .. "/coreutils.exe"
    request.io.close(request.continued.disco)
  end
  if drivers == nil then
    assert(coreutils ~= nil, "internal error: discovery requested without coreutils")
    drivers = H.discover_drivers(request, coreutils)
    assert(drivers[1] ~= nil,
      "no generated OpamLock driver found under etc/dk/v (pass driver=PATH or drivers[]=PATH)")
  end

  local wants = H.import_wants(request)

  if mode == "check" then
    assert(wants ~= nil, "no CommonsLang_OCaml import found in dk.u")
    assert(wants.rulefn ~= nil,
      "import file etc/dk/i/CommonsLang_OCaml." .. wants.ver .. ".values.json missing; run ./dk1 update")
    local stale = {}
    local di = 1
    while drivers[di] ~= nil do
      local D = drivers[di]
      local text = assert(request.ui.readfile { path = D }, "could not read driver `" .. D .. "`")
      local stamp = H.read_stamp(text)
      if stamp == nil then
        local rf = H.first_rulefn(text)
        if rf == nil then
          table.insert(stale, D .. ": unreadable (no stamp and no F_BuildLockedPackage line)")
        else
          if rf ~= wants.rulefn then
            table.insert(stale, H.stale_msg(D, rf, wants.rulefn))
          else
            print("ADVISORY " .. D .. ": unstamped (pre-@1.1.8); run Refresh once to adopt the stamp")
          end
        end
      else
        if stamp.rulefn ~= wants.rulefn then
          table.insert(stale, H.stale_msg(D, stamp.rulefn, wants.rulefn))
        end
        if wants.tool ~= nil and stamp.tool ~= nil and stamp.tool ~= wants.tool then
          table.insert(stale, H.stale_msg(D, stamp.tool, wants.tool))
        end
        if stamp.lock ~= nil then
          local lm = request.ui.checksum { path = stamp.lock }
          if lm ~= nil and lm.sha256 ~= nil then
            local wsha = stamp["lock-sha256"]
            if wsha ~= nil and wsha ~= "" and wsha ~= lm.sha256 then
              table.insert(stale, "STALE " .. D .. ":\n  lock-sha256 stamp " .. wsha
                .. "\n  current " .. stamp.lock .. " " .. lm.sha256
                .. "\n  fix: ./dk1 dialog CommonsLang_OCaml.Dk.OpamLock.Refresh@1.1.10 driver=" .. D)
            end
          else
            print("NOTE " .. D .. ": lock `" .. stamp.lock .. "` not checked in; sha256 check skipped")
          end
        end
      end
      di = di + 1
    end
    if stale[1] ~= nil then
      local sj = 1
      while stale[sj] ~= nil do print(stale[sj]); sj = sj + 1 end
      assert(false, "opam lock/driver check FAILED (" .. H.numstr(H.alen(stale))
        .. " problem(s)); regenerate with the fix command(s) above")
    end
    print("check ok (" .. H.numstr(H.alen(drivers)) .. " driver(s), import " .. wants.ver .. ")")
    return { submit = {} }
  end

  -- Resolve the target per-package build rule: explicit override, else the
  -- newest F_BuildLockedPackage the import declares, else the baked default.
  local targetrule = request.user.rulefn
  if targetrule == nil and wants ~= nil then targetrule = wants.rulefn end
  if targetrule == nil then targetrule = "CommonsLang_OCaml.Dk.OpamBuild.F_BuildLockedPackage@1.0.18" end

  if mode == "solve" then
    local su = H.solve_user(request)
    local sproxy = {
      user = su, ui = request.ui, io = request.io,
      execution = request.execution, continued = request.continued
    }
    uirules.Solve("submit", sproxy, "solve")
  end

  local targettool = nil
  if wants ~= nil then targettool = wants.tool end
  local di = 1
  while drivers[di] ~= nil do
    H.refresh_one(request, drivers[di], targetrule, request.user.version, targettool)
    di = di + 1
  end
  print("refresh complete (" .. H.numstr(H.alen(drivers)) .. " driver(s), rule " .. targetrule .. ")")
  return { submit = {} }
end

-- ---------------------------------------------------------------------------
-- OpamVenv: materialize a dune-usable prefix from the built closure
-- ---------------------------------------------------------------------------

-- Forward-slash form of a path. lua-ml has no gsub; dune and findlib accept the
-- mixed C:/... form on Windows, so backslashes become slashes uniformly.
function CommonsLang_OCaml__Dk_OpamLock__1_1_10.to_slash(s)
  return CommonsLang_OCaml__Dk_OpamLock__1_1_10.replace_all(s, "\\", "/")
end

-- Escape a string for embedding as a JSON string value (backslash, then quote).
function CommonsLang_OCaml__Dk_OpamLock__1_1_10.json_esc(s)
  local H = CommonsLang_OCaml__Dk_OpamLock__1_1_10
  return H.replace_all(H.replace_all(s, "\\", "\\\\"), "\"", "\\\"")
end

-- Backslash form (for Windows PATH entries baked into env.ps1/env.cmd).
function CommonsLang_OCaml__Dk_OpamLock__1_1_10.to_back(s)
  return CommonsLang_OCaml__Dk_OpamLock__1_1_10.replace_all(s, "/", "\\")
end

-- Compare-and-swap write of one project file: checksum the current content
-- (absent -> "false" = must-not-exist) then writefile with that guard. Returns
-- the resolved path.
function CommonsLang_OCaml__Dk_OpamLock__1_1_10.write_projfile(request, path, content)
  local meta = request.ui.checksum { path = path }
  local expected = "false"
  if meta and meta.sha256 then expected = meta.sha256 end
  local ok, written = request.ui.writefile { path = path, content = content, expected_sha256 = expected }
  assert(ok, "could not write `" .. path .. "`: " .. tostring(written))
  return written
end

-- Run a program under the user's project dir, asserting a zero exit; returns
-- the capture result (so callers can read .stdout).
function CommonsLang_OCaml__Dk_OpamLock__1_1_10.run(request, program, args, what)
  local res = request.ui.capture { program = program, args = args, max_output_bytes = 4194304 }
  assert(res, "could not run " .. what)
  assert(res.status == "exit" and res.code == 0,
    what .. " failed (code " .. tostring(res.code) .. "): " .. tostring(res.stderr))
  return res
end

-- Resolve the dev-prefix plan: find the mergedprefix driver (explicit driver=
-- or the sole discovered one), read its stamp, and derive the get-object
-- targets. Returns a table { driver, formid, lock, locksha, slot, ocaml, dune,
-- out }. Needs a materialized coreutils for discovery.
function CommonsLang_OCaml__Dk_OpamLock__1_1_10.opamvenv_plan(request, coreutils)
  local H = CommonsLang_OCaml__Dk_OpamLock__1_1_10
  local drivers = nil
  if request.user.driver ~= nil then
    drivers = { request.user.driver }
  else
    local all = H.discover_drivers(request, coreutils)
    drivers = {}
    local i = 1
    while all[i] ~= nil do
      local t = request.ui.readfile { path = all[i] }
      if t ~= nil then
        local st = H.read_stamp(t)
        if st ~= nil and st.mergedprefix == "t" then table.insert(drivers, all[i]) end
      end
      i = i + 1
    end
    assert(drivers[1] ~= nil,
      "no dev-prefix driver found under etc/dk/v. Generate one first:\n"
      .. "  ./dk1 dialog CommonsLang_OCaml.Dk.OpamLock.GenerateDriver@1.1.10 lock=<LOCK>"
      .. " out=etc/dk/v/<Lib>/<Root>.DevPrefix.values.jsonc root=<ROOT> skiplocal=t"
      .. " mergedprefix=t parallel=t formid=<Lib>.<Root>.DevPrefix@<VER> pkgpath=<Lib>.<Root>"
      .. " version=<VER> rulefn=CommonsLang_OCaml.Dk.OpamBuild.F_BuildLockedPackage@1.0.18"
      .. " localsrc=<SRC> locksrcpath=./dk-opam-lock.jsonc")
    assert(drivers[2] == nil,
      "multiple dev-prefix drivers found under etc/dk/v; pass driver=PATH to select one")
  end
  local D = H.to_slash(drivers[1])
  local text = assert(request.ui.readfile { path = D }, "could not read driver `" .. D .. "`")
  local stamp = H.read_stamp(text)
  assert(stamp ~= nil,
    "driver `" .. D .. "` has no generated stamp; regenerate it with GenerateDriver@1.1.10")
  assert(stamp.mergedprefix == "t",
    "driver `" .. D .. "` is not a dev-prefix driver (mergedprefix != t). Regenerate it with"
    .. " GenerateDriver@1.1.10 ... skiplocal=t mergedprefix=t")
  local P = {}
  P.driver = D
  P.formid = assert(stamp.formid, "driver `" .. D .. "` stamp has no formid")
  P.lock = stamp.lock
  P.locksha = stamp["lock-sha256"]
  local slot = request.user.slot
  if slot == nil then
    local abi = nil
    if request.execution ~= nil then abi = request.execution.ABIv3 end
    assert(abi ~= nil, "could not determine the host ABI; pass slot=Release.<ABI>")
    slot = "Release." .. abi
  end
  P.slot = slot
  if stamp.slots ~= nil then
    local okslot = nil
    local i = 1
    while stamp.slots[i] ~= nil do
      if stamp.slots[i] == slot then okslot = 1 end
      i = i + 1
    end
    assert(okslot ~= nil,
      "slot `" .. slot .. "` is not built by driver `" .. D .. "`; pass a slot= it declares")
  end
  local ocaml = H.kv(text, "ocaml=")
  if ocaml == nil then ocaml = "CommonsLang_OCaml.DkML@4.14.3" end
  P.ocaml = ocaml
  P.dune = request.user.dune or "CommonsLang_OCaml.Dune@3.23.1"
  P.out = request.user.out or "opam-venv"
  return P
end

-- env.ps1: the recommended Windows activator (auto-imports MSVC vcvars).
function CommonsLang_OCaml__Dk_OpamLock__1_1_10.emit_env_ps1(absprefix, absdkml)
  local H = CommonsLang_OCaml__Dk_OpamLock__1_1_10
  local pbin = H.to_back(absprefix) .. "\\bin"
  local dbin = H.to_back(absdkml) .. "\\bin"
  local stub = absprefix .. "/lib/stublibs;" .. absdkml .. "/lib/ocaml/stublibs"
  local L = {}
  table.insert(L, "# Generated by CommonsLang_OCaml.Dk.OpamLock.OpamVenv@1.1.10 -- do not edit.")
  table.insert(L, "# Dot-source to activate:   . .\\opam-venv\\env.ps1")
  table.insert(L, "if (-not (Test-Path '" .. pbin .. "')) {")
  table.insert(L, "  Write-Error 'opam-venv prefix missing (" .. pbin .. "). Re-run: ./dk1 dialog CommonsLang_OCaml.Dk.OpamLock.OpamVenv@1.1.10'; return")
  table.insert(L, "}")
  table.insert(L, "if ($env:DK_OPAM_VENV -eq '" .. absprefix .. "') { Write-Host 'opam venv already active'; return }")
  table.insert(L, "if (-not (Get-Command cl.exe -ErrorAction SilentlyContinue)) {")
  table.insert(L, "  $vswhere = \"${env:ProgramFiles(x86)}\\Microsoft Visual Studio\\Installer\\vswhere.exe\"")
  table.insert(L, "  if (Test-Path $vswhere) {")
  table.insert(L, "    $vsroot = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath")
  table.insert(L, "    $vcvars = Join-Path $vsroot 'VC\\Auxiliary\\Build\\vcvarsall.bat'")
  table.insert(L, "    if (Test-Path $vcvars) {")
  table.insert(L, "      cmd /c \"call \"\"$vcvars\"\" x64 >nul 2>nul && set\" | ForEach-Object {")
  table.insert(L, "        if ($_ -match '^(INCLUDE|LIB|LIBPATH|Path)=(.*)$') { Set-Item ('Env:' + $Matches[1]) $Matches[2] }")
  table.insert(L, "      }")
  table.insert(L, "    } else { Write-Warning 'vcvarsall.bat not found; native linking may fail. Use a x64 Native Tools prompt.' }")
  table.insert(L, "  } else { Write-Warning 'vswhere not found; native linking may fail. Use a x64 Native Tools prompt.' }")
  table.insert(L, "}")
  table.insert(L, "$env:OCAMLPATH = '" .. absprefix .. "/lib'")
  table.insert(L, "$env:OCAMLFIND_CONF = '" .. absprefix .. "/lib/findlib.conf'")
  table.insert(L, "$env:OCAML_TOPLEVEL_PATH = '" .. absprefix .. "/lib/findlib'")
  table.insert(L, "$env:OCAMLTOP_INCLUDE_PATH = '" .. absprefix .. "/lib/findlib'")
  table.insert(L, "$env:OCAMLFIND_LDCONF = '" .. absdkml .. "/lib/ocaml/ld.conf'")
  table.insert(L, "$env:CAML_LD_LIBRARY_PATH = '" .. stub .. "'")
  table.insert(L, "$env:OCAMLLIB = '" .. absdkml .. "/lib/ocaml'")
  table.insert(L, "Remove-Item Env:INSIDE_DUNE -ErrorAction SilentlyContinue")
  table.insert(L, "$env:Path = '" .. pbin .. ";" .. dbin .. ";' + $env:Path")
  table.insert(L, "$env:DK_OPAM_VENV = '" .. absprefix .. "'")
  table.insert(L, "Write-Host 'opam venv active: OCaml 4.14.3 (DkML) + dune, prefix " .. absprefix .. "'")
  return H.join(L, "\n") .. "\n"
end

-- env.cmd: a minimal linear cmd.exe activator (label-free so LF endings are
-- safe). It does not auto-import MSVC; for native builds run it inside a
-- "x64 Native Tools Command Prompt for VS", or use env.ps1.
function CommonsLang_OCaml__Dk_OpamLock__1_1_10.emit_env_cmd(absprefix, absdkml)
  local H = CommonsLang_OCaml__Dk_OpamLock__1_1_10
  local pbin = H.to_back(absprefix) .. "\\bin"
  local dbin = H.to_back(absdkml) .. "\\bin"
  local stub = absprefix .. "/lib/stublibs;" .. absdkml .. "/lib/ocaml/stublibs"
  local L = {}
  table.insert(L, "@echo off")
  table.insert(L, "rem Generated by CommonsLang_OCaml.Dk.OpamLock.OpamVenv@1.1.10 -- do not edit.")
  table.insert(L, "rem Run:  opam-venv\\env.cmd   (for native builds, run inside a x64 Native Tools prompt)")
  table.insert(L, "if not exist \"" .. pbin .. "\\\" echo opam-venv prefix missing; re-run the OpamVenv dialog.")
  table.insert(L, "set \"OCAMLPATH=" .. absprefix .. "/lib\"")
  table.insert(L, "set \"OCAMLFIND_CONF=" .. absprefix .. "/lib/findlib.conf\"")
  table.insert(L, "set \"OCAML_TOPLEVEL_PATH=" .. absprefix .. "/lib/findlib\"")
  table.insert(L, "set \"OCAMLTOP_INCLUDE_PATH=" .. absprefix .. "/lib/findlib\"")
  table.insert(L, "set \"OCAMLFIND_LDCONF=" .. absdkml .. "/lib/ocaml/ld.conf\"")
  table.insert(L, "set \"CAML_LD_LIBRARY_PATH=" .. stub .. "\"")
  table.insert(L, "set \"OCAMLLIB=" .. absdkml .. "/lib/ocaml\"")
  table.insert(L, "set \"INSIDE_DUNE=\"")
  table.insert(L, "set \"PATH=" .. pbin .. ";" .. dbin .. ";%PATH%\"")
  table.insert(L, "set \"DK_OPAM_VENV=" .. absprefix .. "\"")
  table.insert(L, "where cl >nul 2>nul || echo [note] cl not found; for native builds use env.ps1 or a x64 Native Tools prompt.")
  table.insert(L, "echo opam venv active: prefix " .. absprefix)
  return H.join(L, "\n") .. "\n"
end

-- env.sh: POSIX-sh activator, generated for the host it is made on. On Windows
-- it converts PATH entries with cygpath (Git Bash / MSYS2); on Unix it also
-- repairs DkML's baked native_pack_linker path. `iswin` is 1 on a Windows host.
function CommonsLang_OCaml__Dk_OpamLock__1_1_10.emit_env_sh(absprefix, absdkml, iswin)
  local H = CommonsLang_OCaml__Dk_OpamLock__1_1_10
  local L = {}
  table.insert(L, "#!/bin/sh")
  table.insert(L, "# Generated by CommonsLang_OCaml.Dk.OpamLock.OpamVenv@1.1.10 -- do not edit.")
  table.insert(L, "# Activate:  source opam-venv/env.sh")
  table.insert(L, "DK_PREFIX=\"" .. absprefix .. "\"")
  table.insert(L, "DK_DKML=\"" .. absdkml .. "\"")
  table.insert(L, "if [ ! -d \"$DK_PREFIX/lib\" ]; then")
  table.insert(L, "  echo \"opam-venv prefix missing ($DK_PREFIX); re-run the OpamVenv dialog.\" 1>&2")
  table.insert(L, "  return 1 2>/dev/null || exit 1")
  table.insert(L, "fi")
  table.insert(L, "if [ \"$DK_OPAM_VENV\" = \"$DK_PREFIX\" ]; then echo \"opam venv already active\"; return 0 2>/dev/null || exit 0; fi")
  table.insert(L, "export OCAMLPATH=\"$DK_PREFIX/lib\"")
  table.insert(L, "export OCAMLFIND_CONF=\"$DK_PREFIX/lib/findlib.conf\"")
  table.insert(L, "export OCAML_TOPLEVEL_PATH=\"$DK_PREFIX/lib/findlib\"")
  table.insert(L, "export OCAMLTOP_INCLUDE_PATH=\"$DK_PREFIX/lib/findlib\"")
  table.insert(L, "export OCAMLFIND_LDCONF=\"$DK_DKML/lib/ocaml/ld.conf\"")
  table.insert(L, "export OCAMLLIB=\"$DK_DKML/lib/ocaml\"")
  table.insert(L, "unset INSIDE_DUNE")
  if iswin ~= nil then
    table.insert(L, "if command -v cygpath >/dev/null 2>&1; then")
    table.insert(L, "  export CAML_LD_LIBRARY_PATH=\"$(cygpath -mp \"$DK_PREFIX/lib/stublibs:$DK_DKML/lib/ocaml/stublibs\")\"")
    table.insert(L, "  _pb=\"$(cygpath -u \"$DK_PREFIX/bin\")\"; _db=\"$(cygpath -u \"$DK_DKML/bin\")\"")
    table.insert(L, "else")
    table.insert(L, "  export CAML_LD_LIBRARY_PATH=\"$DK_PREFIX/lib/stublibs;$DK_DKML/lib/ocaml/stublibs\"")
    table.insert(L, "  _pb=\"$DK_PREFIX/bin\"; _db=\"$DK_DKML/bin\"")
    table.insert(L, "fi")
    table.insert(L, "PATH=\"$_pb:$_db:$PATH\"; export PATH")
    table.insert(L, "command -v cl >/dev/null 2>&1 || echo \"[note] cl not found; for native builds use env.ps1 or a x64 Native Tools shell.\" 1>&2")
  else
    table.insert(L, "export CAML_LD_LIBRARY_PATH=\"$DK_PREFIX/lib/stublibs:$DK_DKML/lib/ocaml/stublibs\"")
    table.insert(L, "PATH=\"$DK_PREFIX/bin:$DK_DKML/bin:$PATH\"; export PATH")
    table.insert(L, "_oconf=$(ocamlopt -config 2>/dev/null || true)")
    table.insert(L, "_npl=$(printf '%s\\n' \"$_oconf\" | sed -n 's/^native_pack_linker: *//p' | cut -d' ' -f1)")
    table.insert(L, "if [ -n \"$_npl\" ] && [ ! -f \"$_npl\" ]; then")
    table.insert(L, "  _cc=$(printf '%s\\n' \"$_oconf\" | sed -n 's/^c_compiler: *//p' | cut -d' ' -f1)")
    table.insert(L, "  if mkdir -p \"$(dirname \"$_npl\")\" 2>/dev/null; then")
    table.insert(L, "    printf '#!/bin/sh\\nexec %s \"$@\"\\n' \"$_cc\" > \"$_npl\" 2>/dev/null && chmod +x \"$_npl\" 2>/dev/null || true")
    table.insert(L, "  fi")
    table.insert(L, "fi")
  end
  table.insert(L, "export DK_OPAM_VENV=\"$DK_PREFIX\"")
  table.insert(L, "echo \"opam venv active: prefix $DK_PREFIX\"")
  return H.join(L, "\n") .. "\n"
end

-- OpamVenv: materialize a dune-usable opam prefix from the already-built,
-- non-local dependency closure so a developer runs native `dune build -w`
-- against the working tree, instead of dk's per-edit whole-package rebuild.
--
-- Parameters (dk0 dialog CommonsLang_OCaml.Dk.OpamLock.OpamVenv@1.1.10):
--   driver=PATH   the mergedprefix driver (default: discover the sole one whose
--                 stamp has mergedprefix=t)
--   slot=SLOT     the ABI to materialize (default: the host execution ABI)
--   out=DIR       project-relative output dir (default: opam-venv)
--   dune=ID@VER   the Dune object (default: CommonsLang_OCaml.Dune@3.23.1)
--   force=t       rebuild even when the stamp says it is up to date
function uirules.OpamVenv(command, request, continue_)
  local H = CommonsLang_OCaml__Dk_OpamLock__1_1_10
  if command == "ui" then
    print("CommonsLang_OCaml.Dk.OpamLock@1.1.10: opam venv ready. Activate with:")
    print("  Windows PowerShell:  . .\\opam-venv\\env.ps1")
    print("  Windows cmd:         opam-venv\\env.cmd")
    print("  Unix / Git Bash:     source opam-venv/env.sh")
    print("Then:  dune build -w")
    return
  end
  if command ~= "submit" then return end

  local iswin = nil
  if request.execution ~= nil and request.execution.OSFamily == "windows" then iswin = 1 end

  -- Round A: materialize coreutils (for driver discovery and the copy/rewrite
  -- spawns).
  if continue_ ~= "prep" and continue_ ~= "install" then
    return {
      submit = {
        expressions = {
          directories = {
            co = "$(get-object CommonsBase_Std.Coreutils@0.8.0 -s Release.execution_abi -d : -e 'coreutils.exe')"
          }
        },
        andthen = { continue_ = { state = "prep" } }
      }
    }
  end

  local coreutils = H.trim(request.io.realpath(request.continued.co)) .. "/coreutils.exe"

  -- Round B: cheap coherence and up-to-date checks, then materialize the heavy
  -- objects (prefix.zip, DkML, Dune) for the install round.
  if continue_ == "prep" then
    local P = H.opamvenv_plan(request, coreutils)

    local stamppath = P.out .. "/dk-opam-venv.json"
    local prev = request.ui.readfile { path = stamppath }
    if prev ~= nil and request.user.force == nil then
      local jd = require("jsondk")
      local po = jd.decode(prev)
      if po ~= nil and po["lock-sha256"] == P.locksha and po.slot == P.slot
         and po.tool == "CommonsLang_OCaml.Dk.OpamLock.OpamVenv@1.1.10" then
        request.io.close(request.continued.co)
        print("opam venv is up to date (" .. stamppath .. "); pass force=t to rebuild it")
        return { submit = {} }
      end
    end

    if P.lock ~= nil and P.locksha ~= nil and P.locksha ~= "" then
      local lm = request.ui.checksum { path = P.lock }
      assert(lm ~= nil and lm.sha256 ~= nil,
        "driver lock `" .. tostring(P.lock) .. "` is not on disk")
      assert(lm.sha256 == P.locksha,
        "lock `" .. P.lock .. "` changed since the dev-prefix driver was generated.\n"
        .. "  fix: ./dk1 dialog CommonsLang_OCaml.Dk.OpamLock.Refresh@1.1.10 driver=" .. P.driver
        .. "\n       then re-run this dialog")
    end

    request.io.close(request.continued.co)
    return {
      submit = {
        expressions = {
          directories = {
            co = "$(get-object CommonsBase_Std.Coreutils@0.8.0 -s Release.execution_abi -d : -e 'coreutils.exe')",
            prefix = "$(get-object " .. P.formid .. " -s " .. P.slot .. " -m ./prefix.zip -d : -e 'bin/*')",
            dkml = "$(get-object " .. P.ocaml .. " -s " .. P.slot .. " -d : -e 'bin/*' -e 'lib/ocaml/*')",
            dune = "$(get-object " .. P.dune .. " -s " .. P.slot .. " -d : -e 'bin/*')"
          }
        },
        andthen = { continue_ = { state = "install" } }
      }
    }
  end

  -- Round C: install into the durable project tree.
  local P = H.opamvenv_plan(request, coreutils)
  local prefixsrc = H.trim(request.io.realpath(request.continued.prefix))
  local dkmlsrc = H.trim(request.io.realpath(request.continued.dkml))
  local dunesrc = H.trim(request.io.realpath(request.continued.dune))

  local out = P.out
  local prefixdir = out .. "/prefix"
  local dkmldir = out .. "/toolchain/dkml"

  -- Wipe-and-redo: the prefix and toolchain are wholly derived.
  H.run(request, coreutils, { "rm", "-rf", prefixdir, out .. "/toolchain" }, "wipe opam-venv prefix")
  H.run(request, coreutils, { "mkdir", "-p", prefixdir, dkmldir }, "create opam-venv dirs")

  -- Copy the extracted objects out of the wiped-at-next-startup scratch into the
  -- durable project tree.
  H.run(request, coreutils, { "cp", "-R", prefixsrc .. "/.", prefixdir }, "copy prefix")
  H.run(request, coreutils, { "cp", "-R", dkmlsrc .. "/.", dkmldir }, "copy DkML toolchain")
  -- The Dune object member is bin/dune.exe on every slot; stage it into the
  -- prefix bin (Unix also needs the unqualified `dune` name).
  H.run(request, coreutils, { "cp", dunesrc .. "/bin/dune.exe", prefixdir .. "/bin/dune.exe" }, "copy dune.exe")
  if iswin == nil then
    H.run(request, coreutils, { "cp", dunesrc .. "/bin/dune.exe", prefixdir .. "/bin/dune" }, "name dune")
  end

  -- Absolute, forward-slash paths for baking. Ask the tool that will be on PATH
  -- (coreutils realpath) so the form matches what dune and findlib see.
  local rpp = H.run(request, coreutils, { "realpath", prefixdir }, "realpath prefix")
  local absprefix = H.to_slash(H.trim(rpp.stdout))
  local rpd = H.run(request, coreutils, { "realpath", dkmldir }, "realpath dkml")
  local absdkml = H.to_slash(H.trim(rpd.stdout))

  -- @OPAM_IP@ rewrite: each staged lib/<pkg>/dune-package embeds the sentinel in
  -- its (sections ...) so the object stays content-addressed; point it at the
  -- real prefix or dune cannot resolve the library's install paths.
  local lsres = H.run(request, coreutils, { "ls", prefixdir .. "/lib" }, "list prefix lib")
  local libs = H.splitlines(lsres.stdout)
  local li = 1
  while libs[li] ~= nil do
    local d = H.trim(libs[li])
    if d ~= "" then
      local dp = prefixdir .. "/lib/" .. d .. "/dune-package"
      local content = request.ui.readfile { path = dp }
      if content ~= nil and H.indexof_str(content, "@OPAM_IP@") ~= nil then
        H.write_projfile(request, dp, H.replace_all(content, "@OPAM_IP@", absprefix))
      end
    end
    li = li + 1
  end

  -- Rewrite findlib.conf to the staged prefix and compiler (the shipped one
  -- bakes the producer's dead build path). Library search still comes from
  -- OCAMLPATH; this keeps ocamlfind self-consistent.
  local findlibconf = "destdir=\"" .. absprefix .. "/lib\"\n"
    .. "path=\"" .. absprefix .. "/lib\"\n"
    .. "stdlib=\"" .. absdkml .. "/lib/ocaml\"\n"
    .. "ldconf=\"" .. absdkml .. "/lib/ocaml/ld.conf\"\n"
  H.write_projfile(request, prefixdir .. "/lib/findlib.conf", findlibconf)

  -- Activators.
  H.write_projfile(request, out .. "/env.ps1", H.emit_env_ps1(absprefix, absdkml))
  H.write_projfile(request, out .. "/env.cmd", H.emit_env_cmd(absprefix, absdkml))
  H.write_projfile(request, out .. "/env.sh", H.emit_env_sh(absprefix, absdkml, iswin))

  -- Self-ignoring .gitignore so the ephemeral switch never shows in git status.
  H.write_projfile(request, out .. "/.gitignore", "*\n")

  -- A dune marker (bare (dirs)) so a host `dune build` never scans the
  -- staged prefix; mirrors dk0's own self-ignoring of its t/ working dirs.
  H.write_projfile(request, out .. "/dune", "(dirs)\n")

  -- Stamp for the up-to-date short-circuit and for humans.
  local stamp = "{\n"
    .. "  \"tool\": \"CommonsLang_OCaml.Dk.OpamLock.OpamVenv@1.1.10\",\n"
    .. "  \"driver\": \"" .. H.json_esc(P.driver) .. "\",\n"
    .. "  \"lock\": \"" .. H.json_esc(tostring(P.lock)) .. "\",\n"
    .. "  \"lock-sha256\": \"" .. tostring(P.locksha) .. "\",\n"
    .. "  \"slot\": \"" .. P.slot .. "\",\n"
    .. "  \"prefix\": \"" .. H.json_esc(absprefix) .. "\"\n"
    .. "}\n"
  H.write_projfile(request, out .. "/dk-opam-venv.json", stamp)

  request.io.close(request.continued.co)
  request.io.close(request.continued.prefix)
  request.io.close(request.continued.dkml)
  request.io.close(request.continued.dune)
  print("materialized opam venv into " .. out .. " (slot " .. P.slot .. ")")
  return { submit = {} }
end

return M
