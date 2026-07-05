local M = {
  id = "CommonsLang_OCaml.Dk.OpamLock@1.0.0"
}

-- lua-ml does not support local functions, and a "local" variable would be nil
-- inside the rules/uirules function bodies. So a should-be-unique global table
-- holds the helpers, matching the house style in CommonsBase_Std.Extract and
-- CommonsBase_Remote.GitHub.
CommonsLang_OCaml__Dk_OpamLock__1_0_0 = {}

-- The `json` library is not bound in the UI (dialog) phase, so this module uses
-- its own null sentinel and JSON encoder built on the available string library
-- (find/sub/len/byte; no gsub/gmatch/format).
CommonsLang_OCaml__Dk_OpamLock__1_0_0.NULL = {}

rules, uirules = build.newrules(M)

-- dk slot -> OPAMVAR_* overrides used to solve that slot without a native host.
-- opam resolves `os`/`arch` filters (e.g. conf-mingw only when os=win32) from
-- these. Hyphenated opam variables (os-family/os-distribution) cannot be set via
-- an OPAMVAR_ environment name, so only os/arch are overridden here; packages
-- that filter on os-family are validated when the real MlFront lock is generated.
-- lua-ml table constructors do not accept computed ["key"]=value entries, and
-- slot names contain dots, so populate via bracket-index assignment.
CommonsLang_OCaml__Dk_OpamLock__1_0_0.SLOT_VARS = {}
CommonsLang_OCaml__Dk_OpamLock__1_0_0.SLOT_VARS["Release.Windows_x86_64"] = { os = "win32", arch = "x86_64" }
CommonsLang_OCaml__Dk_OpamLock__1_0_0.SLOT_VARS["Release.Windows_x86"]    = { os = "win32", arch = "x86_32" }
CommonsLang_OCaml__Dk_OpamLock__1_0_0.SLOT_VARS["Release.Linux_x86_64"]   = { os = "linux", arch = "x86_64" }
CommonsLang_OCaml__Dk_OpamLock__1_0_0.SLOT_VARS["Release.Linux_x86"]      = { os = "linux", arch = "x86_32" }
CommonsLang_OCaml__Dk_OpamLock__1_0_0.SLOT_VARS["Release.Linux_arm64"]    = { os = "linux", arch = "arm64" }
CommonsLang_OCaml__Dk_OpamLock__1_0_0.SLOT_VARS["Release.Darwin_x86_64"]  = { os = "macos", arch = "x86_64" }
CommonsLang_OCaml__Dk_OpamLock__1_0_0.SLOT_VARS["Release.Darwin_arm64"]   = { os = "macos", arch = "arm64" }

-- lua-ml's string library does not implement gsub, so trim by scanning for the
-- first/last non-space with find (which does support patterns).
function CommonsLang_OCaml__Dk_OpamLock__1_0_0.trim(s)
  if s == nil then return "" end
  local n = string.len(s)
  local a = 1
  while a <= n and string.find(string.sub(s, a, a), "%s") do a = a + 1 end
  if a > n then return "" end
  local b = n
  while b >= 1 and string.find(string.sub(s, b, b), "%s") do b = b - 1 end
  return string.sub(s, a, b)
end

-- Strip one pair of surrounding double quotes if present.
function CommonsLang_OCaml__Dk_OpamLock__1_0_0.unquote(s)
  s = CommonsLang_OCaml__Dk_OpamLock__1_0_0.trim(s)
  if string.len(s) >= 2 and string.sub(s, 1, 1) == "\"" and string.sub(s, -1) == "\"" then
    return string.sub(s, 2, -2)
  end
  return s
end

-- Split into non-empty trimmed lines (lua-ml has no gmatch/generic-for).
function CommonsLang_OCaml__Dk_OpamLock__1_0_0.lines(s)
  local out = {}
  if s == nil then return out end
  local i = 1
  local n = string.len(s)
  while i <= n do
    local j = string.find(s, "\n", i)
    local line
    if j then line = string.sub(s, i, j - 1); i = j + 1
    else line = string.sub(s, i); i = n + 1 end
    local t = CommonsLang_OCaml__Dk_OpamLock__1_0_0.trim(line)
    if t ~= "" then table.insert(out, t) end
  end
  return out
end

-- Split on whitespace into a table of tokens (no captures; lua-ml safe).
function CommonsLang_OCaml__Dk_OpamLock__1_0_0.words(s)
  local out = {}
  local i = 1
  local n = string.len(s)
  while i <= n do
    while i <= n and string.find(string.sub(s, i, i), "%s") do i = i + 1 end
    if i <= n then
      local j = i
      while j <= n and not string.find(string.sub(s, j, j), "%s") do j = j + 1 end
      table.insert(out, string.sub(s, i, j - 1))
      i = j
    else
      i = n + 1
    end
  end
  return out
end

function CommonsLang_OCaml__Dk_OpamLock__1_0_0.join(tbl, sep)
  local r = nil
  local k, v = next(tbl)
  while k do
    if r == nil then
      r = tostring(v)
    else
      r = r .. sep .. tostring(v)
    end
    k, v = next(tbl, k)
  end
  if r == nil then return "" end
  return r
end

function CommonsLang_OCaml__Dk_OpamLock__1_0_0.set_from_list(tbl)
  local set = {}
  if tbl == nil then return set end
  -- Store the value itself (not the boolean true): lua-ml does not reliably
  -- persist/iterate `true` table values.
  local k, v = next(tbl)
  while k do set[tostring(v)] = tostring(v); k, v = next(tbl, k) end
  return set
end

-- Run a program and return its captured result table {status,code,stdout,stderr}.
-- Asserts on spawn failure or (unless allowfailure) non-zero exit.
function CommonsLang_OCaml__Dk_OpamLock__1_0_0.run(request, program, args, envmods, allowfailure)
  local opts = { program = program, args = args, max_output_bytes = 16777211 }
  if envmods then opts.envmods = envmods end
  print("+ " .. program .. " " .. CommonsLang_OCaml__Dk_OpamLock__1_0_0.join(args, " "))
  local result, msg, kind = request.ui.capture(opts)
  if not result then
    assert(allowfailure, "could not run `" .. program .. "`: " .. tostring(kind) .. ": " .. tostring(msg))
    return { status = "capture", code = 255, stdout = "", stderr = tostring(msg) }
  end
  if result.status ~= "exit" or result.code ~= 0 then
    assert(allowfailure, "`" .. program .. "` exited with code " .. tostring(result.code) .. ": " .. tostring(result.stderr))
  end
  return result
end

-- Capture a single opam field verbatim (opam show --field=FIELD KEY).
-- Returns the trimmed field text, or "" when the field is absent/empty.
function CommonsLang_OCaml__Dk_OpamLock__1_0_0.opam_field(request, opam, switchargs, field, key)
  local args = { "show", "--field=" .. field }
  local k, v = next(switchargs)
  while k do table.insert(args, v); k, v = next(switchargs, k) end
  table.insert(args, key)
  local r = CommonsLang_OCaml__Dk_OpamLock__1_0_0.run(request, opam, args, nil, true)
  if r.status ~= "exit" or r.code ~= 0 then return "" end
  return CommonsLang_OCaml__Dk_OpamLock__1_0_0.trim(r.stdout)
end

-- Parse the top-level (brace-depth 0) quoted tokens out of an opam field such as
-- `depends:`. Quoted tokens inside {filters} are version constraints, not names.
function CommonsLang_OCaml__Dk_OpamLock__1_0_0.top_level_quoted(s)
  local names = {}
  local i, n = 1, string.len(s)
  local depth = 0
  while i <= n do
    local c = string.sub(s, i, i)
    if c == "{" then depth = depth + 1; i = i + 1
    elseif c == "}" then depth = depth - 1; i = i + 1
    elseif c == "\"" then
      local j = i + 1
      while j <= n and string.sub(s, j, j) ~= "\"" do j = j + 1 end
      if depth == 0 then table.insert(names, string.sub(s, i + 1, j - 1)) end
      i = j + 1
    else
      i = i + 1
    end
  end
  return names
end

-- Index of the FIRST "." in s (opam names have no dots; the version follows the
-- first dot). Pattern-free since lua-ml treats "." as a magic pattern char.
function CommonsLang_OCaml__Dk_OpamLock__1_0_0.first_dot(s)
  local i = 1
  local n = string.len(s)
  while i <= n do
    if string.sub(s, i, i) == "." then return i end
    i = i + 1
  end
  return nil
end

-- Extract opam checksums ("<algo>=<hex>") from a url.checksum: field. opam's
-- field is authoritative, so any quoted token containing "=" is a checksum
-- (lua-ml patterns do not support the %a/%x classes needed to validate).
function CommonsLang_OCaml__Dk_OpamLock__1_0_0.checksums(s)
  local out = {}
  local toks = CommonsLang_OCaml__Dk_OpamLock__1_0_0.top_level_quoted(s)
  local k, v = next(toks)
  while k do
    if string.find(v, "=") then table.insert(out, v) end
    k, v = next(toks, k)
  end
  if next(out) == nil then
    local u = CommonsLang_OCaml__Dk_OpamLock__1_0_0.unquote(s)
    if string.find(u, "=") then table.insert(out, u) end
  end
  return out
end

-- JSON-escape a string (quotes included). Handles the escapes opam fields
-- actually contain (", \\, newlines, tabs); maps other control bytes to space.
function CommonsLang_OCaml__Dk_OpamLock__1_0_0.json_str(s)
  local out = "\""
  local n = string.len(s)
  local i = 1
  while i <= n do
    local c = string.sub(s, i, i)
    local b = string.byte(s, i)
    if c == "\"" then out = out .. "\\\""
    elseif c == "\\" then out = out .. "\\\\"
    elseif c == "\n" then out = out .. "\\n"
    elseif c == "\r" then out = out .. "\\r"
    elseif c == "\t" then out = out .. "\\t"
    elseif b ~= nil and b < 32 then out = out .. " "
    else out = out .. c end
    i = i + 1
  end
  return out .. "\""
end

-- Recursive JSON encoder. A table is an array when empty or when it has a [1]
-- element; otherwise it is an object. That matches this module's data (objects
-- always have string keys and are never empty).
function CommonsLang_OCaml__Dk_OpamLock__1_0_0.json_encode(v, indent)
  indent = indent or ""
  local child = indent .. "  "
  if v == CommonsLang_OCaml__Dk_OpamLock__1_0_0.NULL or v == nil then return "null" end
  local t = type(v)
  if t == "boolean" then if v then return "true" else return "false" end end
  if t == "number" then return tostring(v) end
  if t == "string" then return CommonsLang_OCaml__Dk_OpamLock__1_0_0.json_str(v) end
  if t == "table" then
    if next(v) == nil then return "[]" end
    if v[1] ~= nil then
      local parts = {}
      local i = 1
      while v[i] ~= nil do
        table.insert(parts, child .. CommonsLang_OCaml__Dk_OpamLock__1_0_0.json_encode(v[i], child))
        i = i + 1
      end
      return "[\n" .. CommonsLang_OCaml__Dk_OpamLock__1_0_0.join(parts, ",\n") .. "\n" .. indent .. "]"
    end
    local parts = {}
    local k, val = next(v)
    while k do
      table.insert(parts, child .. CommonsLang_OCaml__Dk_OpamLock__1_0_0.json_str(tostring(k)) .. ": " .. CommonsLang_OCaml__Dk_OpamLock__1_0_0.json_encode(val, child))
      k, val = next(v, k)
    end
    return "{\n" .. CommonsLang_OCaml__Dk_OpamLock__1_0_0.join(parts, ",\n") .. "\n" .. indent .. "}"
  end
  return "null"
end

-- Idempotently set up the opam solve switch from a pin table (dk-opam-pins.txt).
-- The table lines are: `repo <name> <url>`, `pin <name> <version>`,
-- `float <name>` (# comments ignored). Adds the pinned repositories, creates the
-- empty switch bound to them if absent, applies the version pins, removes pins
-- for floated packages, and (when local_opam_dir is given) path-pins each local
-- project package. This is generic to any opam project, so it lives in the rule
-- rather than in per-OS wrapper scripts.
function CommonsLang_OCaml__Dk_OpamLock__1_0_0.setup_switch(request, opam, switch, pinsfile, local_opam_dir, locals)
  -- Read the pin table from the real project tree. request.io reads the UI
  -- sandbox, not the project, so use request.ui.readfile (the read counterpart
  -- of request.ui.writefile).
  local content = assert(request.ui.readfile { path = pinsfile },
    "could not read pin table `" .. pinsfile .. "`")

  local repos = {}
  local reponames = {}
  local pins = {}
  local floats = {}
  local plines = CommonsLang_OCaml__Dk_OpamLock__1_0_0.lines(content)
  local lk, lv = next(plines)
  while lk do
    if string.sub(lv, 1, 1) ~= "#" then
      local w = CommonsLang_OCaml__Dk_OpamLock__1_0_0.words(lv)
      if w[1] == "repo" and w[2] and w[3] then
        table.insert(repos, { name = w[2], url = w[3] }); table.insert(reponames, w[2])
      elseif w[1] == "pin" and w[2] and w[3] then
        table.insert(pins, { name = w[2], ver = w[3] })
      elseif w[1] == "float" and w[2] then
        table.insert(floats, w[2])
      end
    end
    lk, lv = next(plines, lk)
  end

  -- add repositories globally (ignore "already exists")
  local rk, rv = next(repos)
  while rk do
    CommonsLang_OCaml__Dk_OpamLock__1_0_0.run(request, opam, { "repository", "add", rv.name, rv.url, "--dont-select", "--yes" }, nil, true)
    rk, rv = next(repos, rk)
  end

  -- create the empty switch bound to those repositories if it does not exist
  local swres = CommonsLang_OCaml__Dk_OpamLock__1_0_0.run(request, opam, { "switch", "list", "--short" }, nil, true)
  local swlines = CommonsLang_OCaml__Dk_OpamLock__1_0_0.lines(swres.stdout)
  local have = false
  local sk, sv = next(swlines)
  while sk do if sv == switch then have = true end; sk, sv = next(swlines, sk) end
  if not have then
    CommonsLang_OCaml__Dk_OpamLock__1_0_0.run(request, opam, { "switch", "create", switch, "--empty", "--repositories=" .. CommonsLang_OCaml__Dk_OpamLock__1_0_0.join(reponames, ","), "--yes" }, nil, false)
  end

  -- apply version pins
  local pk, pv = next(pins)
  while pk do
    CommonsLang_OCaml__Dk_OpamLock__1_0_0.run(request, opam, { "pin", "add", "--switch=" .. switch, "-n", "-y", "-k", "version", pv.name, pv.ver }, nil, false)
    pk, pv = next(pins, pk)
  end

  -- remove pins for floated packages (may not be pinned; ignore failure)
  local fk, fv = next(floats)
  while fk do
    CommonsLang_OCaml__Dk_OpamLock__1_0_0.run(request, opam, { "pin", "remove", "--switch=" .. switch, "--no-action", "-y", fv }, nil, true)
    fk, fv = next(floats, fk)
  end

  -- path-pin the local project packages (versionless: opam reads <name>.opam)
  if local_opam_dir and locals then
    local ck, cv = next(locals)
    while ck do
      CommonsLang_OCaml__Dk_OpamLock__1_0_0.run(request, opam, { "pin", "add", "--switch=" .. switch, "-n", "-y", cv, local_opam_dir }, nil, false)
      ck, cv = next(locals, ck)
    end
  end
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
    "Release.Linux_x86_64", "Release.Linux_arm64", "Release.Linux_x86"
  }
  if command == "declareoutput" then
    return {
      declareoutput = {
        return_objects = {
          id = "CommonsLang_OCaml.Dk.OpamLock.Export@1.0.0",
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

-- Pick the opam binary, then run the solve. When `opam=<path>` is given, use
-- that binary directly: this is developer/PATH mode, keeping your own opam (and
-- OPAMROOT) so a differing opam version cannot force an OPAMROOT upgrade. When
-- absent (the hermetic default), fetch opam from the CommonsLang_OCaml.Opam
-- module across a continuation: the first `submit` returns a get-object
-- expression for the opam directory, and dk0 re-invokes with continue_="solve"
-- and the materialized directory in request.continued.opam.
function uirules.Solve(command, request, continue_)
  if command == "ui" then
    print("CommonsLang_OCaml.Dk.OpamLock@1.0.0: lock written.")
    return
  end
  if command ~= "submit" then return end
  if request.user.opam then
    return CommonsLang_OCaml__Dk_OpamLock__1_0_0.do_solve(request, request.user.opam)
  end
  if continue_ ~= "solve" then
    return {
      submit = {
        expressions = {
          dirs = { opam = "$(get-object CommonsLang_OCaml.Opam@2.5.1 -s Release.execution_abi -d :)" }
        },
        andthen = { continue_ = { state = "solve" } }
      }
    }
  end
  local opamexe = CommonsLang_OCaml__Dk_OpamLock__1_0_0.trim(request.io.realpath(request.continued.opam)) .. "/bin/opam"
  if request.execution and request.execution.OSFamily == "windows" then opamexe = opamexe .. ".exe" end
  return CommonsLang_OCaml__Dk_OpamLock__1_0_0.do_solve(request, opamexe)
end

-- Solve each requested slot with the `opam` program, capture per-package
-- metadata, and publish the lock via request.ui.writefile.
function CommonsLang_OCaml__Dk_OpamLock__1_0_0.do_solve(request, opam)
  -- Parameters (dk0 dialog CommonsLang_OCaml.Dk.OpamLock.Solve@1.0.0 key=val ...)
  local out = assert(request.user.out, "please provide 'out=PROJECT_RELATIVE_LOCK_PATH'")
  local roots = assert(request.user.roots, "please provide 'roots[]=PKG1' 'roots[]=PKG2' ...")
  assert(type(roots) == "table", "roots must be a table: 'roots[]=PKG1' 'roots[]=PKG2' ...")
  local slots = assert(request.user.slots, "please provide 'slots[]=Release.Linux_x86_64' ...")
  assert(type(slots) == "table", "slots must be a table: 'slots[]=SLOT1' 'slots[]=SLOT2' ...")
  local locals_set = CommonsLang_OCaml__Dk_OpamLock__1_0_0.set_from_list(request.user.locals)

  local switchargs = {}
  if request.user.switch then table.insert(switchargs, "--switch=" .. request.user.switch) end

  -- When a pin table is supplied, set up the switch from it before solving.
  if request.user.pins then
    assert(request.user.switch, "pins= requires switch=<name> (the switch to set up)")
    CommonsLang_OCaml__Dk_OpamLock__1_0_0.setup_switch(request, opam, request.user.switch, request.user.pins, request.user.local_opam_dir, request.user.locals)
  end

  local rootscsv = CommonsLang_OCaml__Dk_OpamLock__1_0_0.join(roots, ",")

  -- opam version, for non-authoritative provenance.
  local verres = CommonsLang_OCaml__Dk_OpamLock__1_0_0.run(request, opam, { "--version" }, nil, true)
  local opamver = CommonsLang_OCaml__Dk_OpamLock__1_0_0.trim(verres.stdout)

  -- 1. Solve each requested slot. Package keys are '<name>.<version>'.
  local slot_solutions = {}   -- slot -> { opam_vars=..., solution={keys} }
  local all_keys = {}         -- key -> true (union across slots)
  local k, slot = next(slots)
  while k do
    local vars = assert(CommonsLang_OCaml__Dk_OpamLock__1_0_0.SLOT_VARS[slot], "unknown slot `" .. slot .. "` (no OPAMVAR mapping)")
    local envmods = {}
    local vk, vv = next(vars)
    while vk do table.insert(envmods, "+OPAMVAR_" .. vk .. "=" .. vv); vk, vv = next(vars, vk) end

    local args = { "list", "--resolve=" .. rootscsv, "--columns=package", "--short" }
    local sk, sv = next(switchargs)
    while sk do table.insert(args, sv); sk, sv = next(switchargs, sk) end

    local r = CommonsLang_OCaml__Dk_OpamLock__1_0_0.run(request, opam, args, envmods, false)
    local keys = CommonsLang_OCaml__Dk_OpamLock__1_0_0.lines(r.stdout)
    slot_solutions[slot] = { opam_vars = vars, solution = keys }
    local ik, ikey = next(keys)
    while ik do all_keys[ikey] = ikey; ik, ikey = next(keys, ik) end

    k, slot = next(slots, k)
  end

  -- Build the set of solved package NAMES so depends edges can be filtered to the
  -- closure (a dependency outside every slot's solution is not a build edge).
  local name_in_closure = {}
  local ak = next(all_keys)
  while ak do
    local dot = CommonsLang_OCaml__Dk_OpamLock__1_0_0.first_dot(ak)
    if dot then name_in_closure[string.sub(ak, 1, dot - 1)] = ak end
    ak = next(all_keys, ak)
  end

  -- 2. Capture per-package metadata once per unique key (slot-independent: opam
  --    filters live inside the fields and are resolved per-slot at build time).
  local packages = {}
  ak = next(all_keys)
  while ak do
    local dot = CommonsLang_OCaml__Dk_OpamLock__1_0_0.first_dot(ak)
    local name = string.sub(ak, 1, dot - 1)
    local version = string.sub(ak, dot + 1)

    local url = CommonsLang_OCaml__Dk_OpamLock__1_0_0.unquote(CommonsLang_OCaml__Dk_OpamLock__1_0_0.opam_field(request, opam, switchargs, "url.src:", ak))
    local sums = CommonsLang_OCaml__Dk_OpamLock__1_0_0.checksums(CommonsLang_OCaml__Dk_OpamLock__1_0_0.opam_field(request, opam, switchargs, "url.checksum:", ak))
    local depends_raw = CommonsLang_OCaml__Dk_OpamLock__1_0_0.opam_field(request, opam, switchargs, "depends:", ak)
    local build_raw = CommonsLang_OCaml__Dk_OpamLock__1_0_0.opam_field(request, opam, switchargs, "build:", ak)
    local install_raw = CommonsLang_OCaml__Dk_OpamLock__1_0_0.opam_field(request, opam, switchargs, "install:", ak)

    -- direct dep names that are in the closure
    local depends = {}
    local depnames = CommonsLang_OCaml__Dk_OpamLock__1_0_0.top_level_quoted(depends_raw)
    local dk, dname = next(depnames)
    while dk do
      if name_in_closure[dname] and dname ~= name then table.insert(depends, dname) end
      dk, dname = next(depnames, dk)
    end

    local is_local = locals_set[name] ~= nil
    local source
    if is_local or url == "" or next(sums) == nil then
      source = CommonsLang_OCaml__Dk_OpamLock__1_0_0.NULL   -- local pin, or a virtual/compiler package with no archive
    else
      source = { url = url, checksums = sums }
    end

    packages[ak] = {
      name = name,
      version = version,
      source = source,
      depends = depends,
      depends_raw = (depends_raw ~= "" and depends_raw or CommonsLang_OCaml__Dk_OpamLock__1_0_0.NULL),
      build = (build_raw ~= "" and build_raw or CommonsLang_OCaml__Dk_OpamLock__1_0_0.NULL),
      install = (install_raw ~= "" and install_raw or CommonsLang_OCaml__Dk_OpamLock__1_0_0.NULL)
    }
    -- "local" is a Lua keyword so it cannot be a constructor identifier key;
    -- set the JSON "local" field via bracket-index assignment.
    packages[ak]["local"] = is_local

    ak = next(all_keys, ak)
  end

  -- 3. Record opam repositories (url + pinned commit for reproducibility).
  -- `opam repository list --all` prints a `#`-prefixed header then rows of
  -- "name  url  switches(rank)..."; take the first two whitespace tokens.
  local repos = {}
  local rr = CommonsLang_OCaml__Dk_OpamLock__1_0_0.run(request, opam, { "repository", "list", "--all" }, nil, true)
  local rlines = CommonsLang_OCaml__Dk_OpamLock__1_0_0.lines(rr.stdout)
  local rlk, rline = next(rlines)
  while rlk do
    if string.sub(rline, 1, 1) ~= "#" then
      local w = CommonsLang_OCaml__Dk_OpamLock__1_0_0.words(rline)
      if w[1] and w[2] then
        table.insert(repos, { name = w[1], url = w[2], commit = request.user.repo_commit or CommonsLang_OCaml__Dk_OpamLock__1_0_0.NULL })
      end
    end
    rlk, rline = next(rlines, rlk)
  end
  if next(repos) == nil then
    table.insert(repos, { url = (request.user.repo_url or "unknown"), commit = request.user.repo_commit or CommonsLang_OCaml__Dk_OpamLock__1_0_0.NULL })
  end

  -- 4. Assemble and write the lock.
  local lock = {
    schema_version = { major = 1, minor = 0 },
    generated = { tool = "CommonsLang_OCaml.Dk.OpamLock@1.0.0", opam_version = opamver },
    opam_repositories = repos,
    packages = packages,
    slots = slot_solutions
  }
  -- "$schema" is not a valid constructor identifier key; assign it.
  lock["$schema"] = "https://diskuv.com/dk/schema/dk-opam-lock-1.0.json"

  -- Publish the lock into the checked-in project tree with a compare-and-swap
  -- guard: the file must be absent (first generation) or unchanged since the
  -- checksum taken just above (regeneration), so a concurrent writer is never
  -- silently clobbered. request.ui.checksum returns nil for a missing file.
  local body = CommonsLang_OCaml__Dk_OpamLock__1_0_0.json_encode(lock, "") .. "\n"
  -- Use the string "false" (not the Lua boolean) for the absent case: a boolean
  -- false is dropped by the lua-ml table-to-record marshaling.
  local meta = request.ui.checksum { path = out }
  local expected = "false"
  if meta and meta.sha256 then expected = meta.sha256 end
  local ok, written = request.ui.writefile { path = out, content = body, expected_sha256 = expected }
  assert(ok, "could not write opam lock to `" .. out .. "`: " .. tostring(written))
  print("wrote opam lock to " .. tostring(written))
  return { submit = {} }
end

return M
