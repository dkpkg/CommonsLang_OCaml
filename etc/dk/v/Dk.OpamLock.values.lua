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
function CommonsLang_OCaml__Dk_OpamLock__1_0_0.iswhite(c)
  local b = string.byte(c)
  return b == 32 or b == 9 or b == 13 or b == 10
end

-- Explicit whitespace checks (space/tab/CR/LF by byte value: raw control
-- bytes and \r are unrepresentable in lua-ml string literals): lua-ml's %s
-- class does not match CR, which left a trailing CR on every line of CRLF
-- opam output on Windows (ex. the
-- switch-exists check compared name-plus-CR ~= name and re-created the
-- switch).
function CommonsLang_OCaml__Dk_OpamLock__1_0_0.trim(s)
  if s == nil then return "" end
  local n = string.len(s)
  local a = 1
  while a <= n and CommonsLang_OCaml__Dk_OpamLock__1_0_0.iswhite(string.sub(s, a, a)) do a = a + 1 end
  if a > n then return "" end
  local b = n
  while b >= 1 and CommonsLang_OCaml__Dk_OpamLock__1_0_0.iswhite(string.sub(s, b, b)) do b = b - 1 end
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
    while i <= n and CommonsLang_OCaml__Dk_OpamLock__1_0_0.iswhite(string.sub(s, i, i)) do i = i + 1 end
    if i <= n then
      local j = i
      while j <= n and not CommonsLang_OCaml__Dk_OpamLock__1_0_0.iswhite(string.sub(s, j, j)) do j = j + 1 end
      table.insert(out, string.sub(s, i, j - 1))
      i = j
    else
      i = n + 1
    end
  end
  return out
end

-- Join an ARRAY's elements in index order. Iterating with next() (as an earlier
-- version did) walks lua-ml's arbitrary hash order, which silently scrambled the
-- order of every joined array -- including the JSON encoder's `parts`, so a
-- sorted key list still emitted unsorted. Walk 1..n instead.
function CommonsLang_OCaml__Dk_OpamLock__1_0_0.join(tbl, sep)
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

function CommonsLang_OCaml__Dk_OpamLock__1_0_0.set_from_list(tbl)
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
function CommonsLang_OCaml__Dk_OpamLock__1_0_0.dirname(p)
  local i = string.len(p)
  while i >= 1 do
    local b = string.byte(p, i)
    if b == 47 or b == 92 then return string.sub(p, 1, i - 1) end
    i = i - 1
  end
  return "."
end

-- Run a program and return its captured result table {status,code,stdout,stderr}.
-- Asserts on spawn failure or (unless allowfailure) non-zero exit.
function CommonsLang_OCaml__Dk_OpamLock__1_0_0.run(request, program, args, envmods, allowfailure)
  local opts = { program = program, args = args, max_output_bytes = 16777211 }
  if envmods then opts.envmods = envmods end
  print("+ " .. program .. " " .. CommonsLang_OCaml__Dk_OpamLock__1_0_0.join(args, " "))
  -- allowfailure is a truthy NUMBER (1), never a boolean: lua-ml drops a boolean
  -- literal passed as a trailing call argument (it arrives as nil), so tolerant
  -- callers pass 1 and strict callers omit it. Branch on `not allowfailure` and
  -- raise via assert(false, ...) so no assert-of-a-truthy-value is relied on.
  local result, msg, kind = request.ui.capture(opts)
  if not result then
    if not allowfailure then
      assert(false, "could not run `" .. program .. "`: " .. tostring(kind) .. ": " .. tostring(msg))
    end
    return { status = "capture", code = 255, stdout = "", stderr = tostring(msg) }
  end
  if (result.status ~= "exit" or result.code ~= 0) and not allowfailure then
    assert(false, "`" .. program .. "` exited with code " .. tostring(result.code) .. ": " .. tostring(result.stderr))
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
  local r = CommonsLang_OCaml__Dk_OpamLock__1_0_0.run(request, opam, args, nil, 1)
  if r.status ~= "exit" or r.code ~= 0 then return "" end
  return CommonsLang_OCaml__Dk_OpamLock__1_0_0.trim(r.stdout)
end

-- Capture the requested `--field`s for MANY packages, batching them across as
-- few `opam show` invocations as fit safely in one command line. opam accepts
-- multiple package keys and prints each package's fields in the requested order,
-- so this replaces (#packages * #fields) separate `opam show` runs -- the
-- dominant cost of the solve. Returns pkgkey -> { [field] = value } where each
-- value equals what a single-field `opam show --field=X <pkg>` returns.
--
-- Chunking: a command line naming every key could exceed a platform limit and be
-- silently truncated (Windows CreateProcess ~32 KB, the stricter cmd.exe/legacy
-- paths ~8 KB, Unix ARG_MAX is larger). So the keys are split into chunks whose
-- joined length stays well under the smallest limit; one `opam show` runs per
-- chunk and the per-package results merge into one table.
--
-- A chunk also never names the same package at two versions: `opam show`
-- collapses repeated same-name atoms into one impossible version constraint and
-- prints NO block for either (ex. the closure holds ppx_inline_test at both
-- v0.16.0 and v0.16.1). A dropped block would shift every field after it in a
-- position-based parse, so split same-name keys into separate chunks; the parser
-- keys each block by its own name.version and merges across chunks.
function CommonsLang_OCaml__Dk_OpamLock__1_0_0.opam_show_all(request, opam, switchargs, fields, keylist)
  local H = CommonsLang_OCaml__Dk_OpamLock__1_0_0
  local by_key = {}
  -- Budget only the key-list portion of the command line. 6000 leaves ample
  -- headroom for the program path, "show", --field and --switch and still clears
  -- the ~8 KB cmd.exe/legacy cap; a chunk boundary never splits a key.
  local MAXKEYS = 6000
  local total = 0; local tk = next(keylist); while tk do total = total + 1; tk = next(keylist, tk) end
  local chunk = {}
  local chunknames = {}
  local chunklen = 0
  local ci = 1
  while ci <= total do
    local key = keylist[ci]
    local klen = string.len(key) + 1
    local dot = H.first_dot(key)
    local nm = key; if dot then nm = string.sub(key, 1, dot - 1) end
    if chunk[1] ~= nil and (chunklen + klen > MAXKEYS or chunknames[nm] ~= nil) then
      H.opam_show_chunk(request, opam, switchargs, fields, chunk, by_key)
      chunk = {}; chunknames = {}; chunklen = 0
    end
    table.insert(chunk, key); chunknames[nm] = nm; chunklen = chunklen + klen
    ci = ci + 1
  end
  if chunk[1] ~= nil then H.opam_show_chunk(request, opam, switchargs, fields, chunk, by_key) end
  return by_key
end

-- Parse ONE `opam show` over a chunk of package keys, merging into by_key.
-- Output shape (multi package, multi field): each field prints "<field>:" at
-- column 0, its value aligned to column (longest field name + 1), and any
-- continuation lines indented to that column; an empty field prints "<field>:".
--
-- `name:`/`version:` are prepended to the requested fields so every package
-- block opens with `name:` (opam always emits both, even for virtual/base
-- packages that have no url) and each block is keyed by its OWN `name.version`
-- rather than by position. Position-based matching silently corrupted the lock
-- whenever opam emitted fewer blocks than keys requested -- a dropped block (see
-- opam_show_all's same-name note) shifted every later package's fields onto the
-- wrong key.
--
-- De-indenting every line by the alignment width W = (longest requested field
-- name + 1) strips the "<field>:"/padding column and recovers the single-field
-- text; splitting on "\n" only (not "\r\n") keeps the CRLF that a Windows opam
-- emits inside multi-line values, so the captured text is byte-identical to a
-- per-field `opam show`.
function CommonsLang_OCaml__Dk_OpamLock__1_0_0.opam_show_chunk(request, opam, switchargs, fields, keylist, by_key)
  local H = CommonsLang_OCaml__Dk_OpamLock__1_0_0
  -- request fields = name:, version: (identity), then the caller's data fields
  local reqfields = { "name:", "version:" }
  local rf, rv = next(fields)
  while rf do table.insert(reqfields, rv); rf, rv = next(fields, rf) end

  local args = { "show", "--field=" .. H.join(reqfields, ",") }
  local sk, sv = next(switchargs)
  while sk do table.insert(args, sv); sk, sv = next(switchargs, sk) end
  local kk, kv = next(keylist)
  while kk do table.insert(args, kv); kk, kv = next(keylist, kk) end
  local r = H.run(request, opam, args, nil, 1)
  -- Parse whatever ran: opam warns on stderr and still exits 0 for a missing
  -- key, but even a non-zero exit leaves the good blocks on stdout, so do not
  -- discard them; a genuinely failed spawn leaves stdout empty and yields none.
  if r.status ~= "exit" then return end

  -- field membership set, the boundary field, and the alignment width W. Walk by
  -- index so firstfield is reqfields[1] (`name:`) -- opam emits fields in the
  -- order passed to --field=, which is join(reqfields) in index order, so the
  -- parser's package boundary must key off the same first field.
  local fset = {}
  local firstfield = reqfields[1]
  local W = 0
  local fi = 1
  while reqfields[fi] ~= nil do
    local fv = reqfields[fi]
    fset[fv] = fv
    local l = string.len(fv); if l + 1 > W then W = l + 1 end
    fi = fi + 1
  end

  -- split stdout into raw lines (keep leading whitespace for the column-0 test
  -- and the trailing CR so multi-line values keep their CRLF)
  local rl = {}
  local raw = r.stdout or ""
  local i, n = 1, string.len(raw)
  while i <= n do
    local j = string.find(raw, "\n", i)
    if j then table.insert(rl, string.sub(raw, i, j - 1)); i = j + 1
    else table.insert(rl, string.sub(raw, i)); i = n + 1 end
  end
  local nlines = 0; local ck = next(rl); while ck do nlines = nlines + 1; ck = next(rl, ck) end

  -- lua-ml: iterate by numeric index (next() order is not guaranteed); use
  -- nil/non-nil, not boolean, for the "have a current field/package" test.
  -- Each `name:` boundary finalizes the previous package (key = its own
  -- name.version) before starting the next; the tail is finalized after the loop.
  local cur = nil          -- field table for the package currently being parsed
  local curfield = nil
  local buf = ""
  local idx = 1
  while idx <= nlines do
    local line = rl[idx]
    local p, ll = 1, string.len(line)
    while p <= ll and not H.iswhite(string.sub(line, p, p)) do p = p + 1 end
    local token = string.sub(line, 1, p - 1)   -- leading non-space token
    if fset[token] ~= nil then
      if cur ~= nil and curfield ~= nil then cur[curfield] = H.trim(buf) end
      if token == firstfield then
        if cur ~= nil then
          local nm = H.unquote(cur["name:"] or "")
          local vr = H.unquote(cur["version:"] or "")
          if nm ~= "" and vr ~= "" then by_key[nm .. "." .. vr] = cur end
        end
        cur = {}
      end
      curfield = token
      buf = string.sub(line, W + 1)
    else
      if curfield ~= nil then buf = buf .. "\n" .. string.sub(line, W + 1) end
    end
    idx = idx + 1
  end
  if cur ~= nil and curfield ~= nil then cur[curfield] = H.trim(buf) end
  if cur ~= nil then
    local nm = H.unquote(cur["name:"] or "")
    local vr = H.unquote(cur["version:"] or "")
    if nm ~= "" and vr ~= "" then by_key[nm .. "." .. vr] = cur end
  end
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

-- Build the opam content-addressed cache URL from a checksum list. The opam
-- repository mirrors every published archive at
-- `https://opam.ocaml.org/cache/<kind>/<first2hex>/<hash>` keyed by its
-- checksum, so this URL is stable, byte-reproducible (unlike a GitHub
-- auto-generated archive, whose bytes and thus checksum can drift), and always
-- returns a Content-Length. Preferring it fixes both lock reproducibility (R4)
-- and the source-size HEAD probe. Prefer an opam-recorded kind (sha512 > md5 >
-- sha256) so the cache always serves it: a sha256 this rule *computed* for a
-- package opam shipped as md5/sha512-only is NOT in the cache, so sha256 is the
-- last resort. Returns nil when no usable checksum is present.
function CommonsLang_OCaml__Dk_OpamLock__1_0_0.cache_url(sums)
  local sha512, md5, sha256 = "", "", ""
  local k, v = next(sums)
  while k do
    if string.sub(v, 1, 7) == "sha512=" then sha512 = string.sub(v, 8)
    elseif string.sub(v, 1, 7) == "sha256=" then sha256 = string.sub(v, 8)
    elseif string.sub(v, 1, 4) == "md5=" then md5 = string.sub(v, 5) end
    k, v = next(sums, k)
  end
  local kind, hex = "", ""
  if sha512 ~= "" then kind = "sha512"; hex = sha512
  elseif md5 ~= "" then kind = "md5"; hex = md5
  elseif sha256 ~= "" then kind = "sha256"; hex = sha256 end
  if string.len(hex) < 2 then return nil end
  return "https://opam.ocaml.org/cache/" .. kind .. "/" .. string.sub(hex, 1, 2) .. "/" .. hex
end

-- True when the checksum list already carries a kind that a dk bundle asset can
-- express (sha256/sha1/blake2b256). opam records md5/sha512 for older packages,
-- which a bundle cannot represent, so those need a computed sha256.
-- Classify a source archive by its URL basename extension. The build-time rule
-- fetches from the opam cache whose filename is a bare hash (no extension), so
-- the archive type must be recorded explicitly. Defaults to tgz (opam's common
-- case) when the extension is unrecognized.
function CommonsLang_OCaml__Dk_OpamLock__1_0_0.archive_type(url)
  local n = string.len(url)
  if string.sub(url, n - 6) == ".tar.gz" or string.sub(url, n - 3) == ".tgz" then return "tgz" end
  if string.sub(url, n - 6) == ".tar.xz" or string.sub(url, n - 3) == ".txz" then return "txz" end
  if string.sub(url, n - 7) == ".tar.bz2" or string.sub(url, n - 3) == ".tbz" then return "tbz" end
  if string.sub(url, n - 3) == ".tar" then return "tar" end
  return "tgz"
end

-- Returns 1 when the checksum list carries a bundle-expressible kind
-- (sha256/sha1/blake2b256), else 0. Numeric, not boolean: lua-ml `return true`/
-- `return false` both come back as nil, so a boolean result is unusable.
function CommonsLang_OCaml__Dk_OpamLock__1_0_0.has_bundle_checksum(sums)
  local k, v = next(sums)
  while k do
    if string.sub(v, 1, 7) == "sha256=" then return 1 end
    if string.sub(v, 1, 5) == "sha1=" then return 1 end
    if string.sub(v, 1, 11) == "blake2b256=" then return 1 end
    k, v = next(sums, k)
  end
  return 0
end

-- Compute the sha256 of a source archive by downloading it and hashing. Used
-- only when opam offers no bundle-compatible checksum. curl saves the archive to
-- the capture working directory; certutil (always present on Windows) prints the
-- hash. Returns a lowercase hex sha256, or nil on any failure.
function CommonsLang_OCaml__Dk_OpamLock__1_0_0.source_sha256(request, url)
  -- Windows-only (certutil). Mirror source_size's exact positive OSFamily test
  -- (lua-ml mishandles a `local x = nil` binding and a negated `not (A and B)`
  -- guard, both of which silently no-op'd this function).
  local curlexe = "curl"
  local iswin = 0
  if request.execution and request.execution.OSFamily == "windows" then
    curlexe = "C:\\Windows\\System32\\curl.exe"
    iswin = 1
  end
  if iswin == 0 then return nil end
  local certutil = "C:\\Windows\\System32\\certutil.exe"
  local tmp = "dk-opamlock-src.download"
  local dl = CommonsLang_OCaml__Dk_OpamLock__1_0_0.run(request, curlexe, { "-f", "-sL", "-o", tmp, url }, nil, 1)
  if dl.status ~= "exit" or dl.code ~= 0 then return nil end
  local h = CommonsLang_OCaml__Dk_OpamLock__1_0_0.run(request, certutil, { "-hashfile", tmp, "SHA256" }, nil, 1)
  if h.status ~= "exit" or h.code ~= 0 then return nil end
  -- certutil prints the 64-hex digest on its own line (may contain spaces on old
  -- builds); find the line that is 64 hex characters after removing spaces.
  local lns = CommonsLang_OCaml__Dk_OpamLock__1_0_0.lines(h.stdout)
  local lk, ln = next(lns)
  while lk do
    local hex = ""
    local i = 1
    local n = string.len(ln)
    while i <= n do
      local c = string.lower(string.sub(ln, i, i))
      if (c >= "0" and c <= "9") or (c >= "a" and c <= "f") then hex = hex .. c end
      i = i + 1
    end
    if string.len(hex) == 64 then return hex end
    lk, ln = next(lns, lk)
  end
  return nil
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

-- Byte-wise lexicographic `a < b` for strings (lua-ml's string `<` operator is
-- not relied upon). Returns 1 (true) or nil (false), the module's truth style.
function CommonsLang_OCaml__Dk_OpamLock__1_0_0.str_lt(a, b)
  local la = string.len(a); local lb = string.len(b)
  local n = la; if lb < n then n = lb end
  local i = 1
  while i <= n do
    -- string.byte(s, i) (two-arg, byte at index) is unreliable in lua-ml; take a
    -- one-character slice and byte it, the pattern the rest of the module uses.
    local ca = string.byte(string.sub(a, i, i)); local cb = string.byte(string.sub(b, i, i))
    if ca < cb then return 1 end
    if ca > cb then return nil end
    i = i + 1
  end
  if la < lb then return 1 end
  return nil
end

-- In-place insertion sort of a string array (small arrays; keeps the lock's
-- package/solution ordering canonical and reproducible regardless of the order
-- opam happens to emit -- version-pins and the constraints repo resolve the same
-- closure but list it differently).
-- Returns the sorted array. In-place mutation of a table argument does not
-- reliably propagate back to the caller in lua-ml, so callers must use the
-- RETURN value (`a = sort_str_array(a)`), not rely on `a` being sorted in place.
function CommonsLang_OCaml__Dk_OpamLock__1_0_0.sort_str_array(a)
  local n = 0; local c = next(a); while c do n = n + 1; c = next(a, c) end
  local i = 2
  while i <= n do
    local key = a[i]; local j = i - 1
    while j >= 1 and CommonsLang_OCaml__Dk_OpamLock__1_0_0.str_lt(key, a[j]) do a[j + 1] = a[j]; j = j - 1 end
    a[j + 1] = key; i = i + 1
  end
  return a
end

-- The keys of a map as a lexicographically sorted array.
function CommonsLang_OCaml__Dk_OpamLock__1_0_0.sorted_keys(m)
  local ks = {}
  local k = next(m)
  while k do table.insert(ks, tostring(k)); k = next(m, k) end
  return CommonsLang_OCaml__Dk_OpamLock__1_0_0.sort_str_array(ks)
end

-- Recursive JSON encoder. A table is an array when empty or when it has a [1]
-- element; otherwise it is an object with keys emitted in sorted order (so the
-- lock is byte-stable). That matches this module's data (objects always have
-- string keys and are never empty).
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
    local ks = CommonsLang_OCaml__Dk_OpamLock__1_0_0.sorted_keys(v)
    local ki = 1
    while ks[ki] do
      local k = ks[ki]
      table.insert(parts, child .. CommonsLang_OCaml__Dk_OpamLock__1_0_0.json_str(k) .. ": " .. CommonsLang_OCaml__Dk_OpamLock__1_0_0.json_encode(v[k], child))
      ki = ki + 1
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
--
-- `fresh` (an ephemeral switch created empty this run) skips the float pass: a
-- `float` un-pins a package the pin table shares with a persistent build switch,
-- but an empty switch has nothing pinned, so every `opam pin remove` is a slow
-- no-op. Floats still run for a reused persistent switch, where a prior run may
-- have left the package pinned.
function CommonsLang_OCaml__Dk_OpamLock__1_0_0.setup_switch(request, opam, switch, pinsfile, local_opam_dir, winlocs, fresh)
  -- Read the pin table from the real project tree. request.io reads the UI
  -- sandbox, not the project, so use request.ui.readfile (the read counterpart
  -- of request.ui.writefile).
  local content = assert(request.ui.readfile { path = pinsfile },
    "could not read pin table `" .. pinsfile .. "`")

  local repos = {}
  local reponames = {}
  local pins = {}
  local floats = {}
  local archexcludes = {}
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
      elseif w[1] == "archexclude" and w[2] and w[3] then
        -- `archexclude PKG ARCH` conflicts PKG on slots whose arch = ARCH,
        -- disambiguating an opam disjunction the upstream package leaves
        -- arch-agnostic (e.g. system-mingw's `ocaml-env-mingw32|64`). Ignored by
        -- ci/build-all.sh (its case falls through), so it is safe in the shared
        -- table.
        table.insert(archexcludes, { name = w[2], arch = w[3] })
      end
    end
    lk, lv = next(plines, lk)
  end

  -- Emit a single-package custom opam repository whose meta-package locks every
  -- pinned version, replacing the 193 individual `opam pin add -k version` calls
  -- that dominated the solve wall-clock. The versions live in CONFLICTS
  -- (`"pkg" {!= "ver"}`), not depends: a conflict constrains a package's version
  -- only when the roots' closure already pulls it in -- exactly a version pin --
  -- whereas depends would force all 193 (a superset of any slot's ~94-package
  -- closure) into the lock. Floated packages are absent from the pin list, so
  -- they stay unconstrained.
  local H = CommonsLang_OCaml__Dk_OpamLock__1_0_0
  local constraints_pkg = nil
  local archpkgs = {}
  local csrepo_url = nil
  if pins[1] ~= nil then
    constraints_pkg = "dk-solve-constraints"
    local rf = assert(request.io.open("csrepo/repo", "w"), "could not open csrepo/repo")
    request.io.write(rf, "opam-version: \"2.0\"\n")
    request.io.flush(rf)
    local rfabs = H.trim(request.io.realpath(rf))
    csrepo_url = H.dirname(rfabs)
    request.io.close(rf)
    local cspath = "csrepo/packages/dk-solve-constraints/dk-solve-constraints.1/opam"
    local cf = assert(request.io.open(cspath, "w"), "could not open the constraints meta-package")
    request.io.write(cf, "opam-version: \"2.0\"\n")
    request.io.write(cf, "synopsis: \"Generated version lock for the dk opam solve\"\n")
    request.io.write(cf, "conflicts: [\n")
    local xk, xv = next(pins)
    while xk do
      request.io.write(cf, "  \"" .. xv.name .. "\" {!= \"" .. xv.ver .. "\"}\n")
      xk, xv = next(pins, xk)
    end
    request.io.write(cf, "]\n")
    request.io.flush(cf)
    request.io.close(cf)

    -- Per-arch exclusion packages (see the `archexclude` directive). opam does
    -- NOT honour a FILTER inside a conflict (`"pkg" {arch = "x"}` is ignored),
    -- but an UNCONDITIONAL conflict does force an otherwise arch-agnostic
    -- disjunction (e.g. system-mingw's `ocaml-env-mingw32|64`). So group the
    -- exclusions by arch and emit one package per arch whose conflicts are
    -- unconditional; the caller adds `dk-solve-arch-<arch>` only to the resolve
    -- of a slot whose arch matches, and a package absent from that slot's closure
    -- makes its conflict a harmless no-op.
    local archmap = {}
    local ek, ev = next(archexcludes)
    while ek do
      if archmap[ev.arch] == nil then archmap[ev.arch] = {} end
      table.insert(archmap[ev.arch], ev.name)
      ek, ev = next(archexcludes, ek)
    end
    local mk, mv = next(archmap)
    while mk do
      local apkg = "dk-solve-arch-" .. mk
      local apath = "csrepo/packages/" .. apkg .. "/" .. apkg .. ".1/opam"
      local af = assert(request.io.open(apath, "w"), "could not open arch exclusion package " .. apkg)
      request.io.write(af, "opam-version: \"2.0\"\n")
      request.io.write(af, "synopsis: \"Generated arch exclusions for the dk opam solve\"\n")
      request.io.write(af, "conflicts: [\n")
      local ck = next(mv)
      while ck do
        request.io.write(af, "  \"" .. mv[ck] .. "\"\n")
        ck = next(mv, ck)
      end
      request.io.write(af, "]\n")
      request.io.flush(af)
      request.io.close(af)
      archpkgs[mk] = apkg
      mk, mv = next(archmap, mk)
    end
  end

  -- initialise the opam root if needed. The hermetic module-opam path
  -- starts from a fresh OPAMROOT (a developer's PATH opam is normally
  -- already initialised), and every later command needs an initialised
  -- root. --bare skips the compiler switch. An init config file written to
  -- the UI sandbox seeds ALL pinned repositories at once, so the large
  -- upstream default repository is never fetched. --disable-sandboxing
  -- keeps Linux containers without bwrap working (the lock solve never
  -- builds packages, so no sandbox is needed).
  local ini = CommonsLang_OCaml__Dk_OpamLock__1_0_0.run(request, opam, { "var", "root", "--global" }, nil, 1)
  if ini.status ~= "exit" or ini.code ~= 0 then
    local initargs = { "init", "--bare", "--no-setup", "--disable-sandboxing", "--yes" }
    if winlocs then
      -- Provide the dk-packaged MSYS2 tree and MinGit instead of letting
      -- opam install an internal Cygwin (~224 MB downloaded from Cygwin
      -- mirrors at solve time, ~2 minutes, not hermetic). opam has no
      -- msys2-named options: the --cygwin-* family is its only Unix
      -- infrastructure interface and accepts MSYS2 trees (detection keys
      -- off usr/bin/cygpath.exe). --git-location wants the directory
      -- holding git.exe WITHOUT a bash beside it (MinGit cmd/). These
      -- opam options are marked experimental; the owner accepted that
      -- risk explicitly.
      table.insert(initargs, "--cygwin-local-install")
      table.insert(initargs, "--cygwin-location=" .. winlocs.msys2)
      table.insert(initargs, "--git-location=" .. winlocs.git)
    end
    if repos[1] then
      local rcfile = assert(request.io.open("opamrc-bootstrap", "w"), "could not open opamrc-bootstrap for write")
      request.io.write(rcfile, "opam-version: \"2.0\"\n")
      request.io.write(rcfile, "# Generated by CommonsLang_OCaml.Dk.OpamLock for hermetic lock solving.\n")
      request.io.write(rcfile, "# Why each setting: this root only ever SOLVES dependencies (an empty\n")
      request.io.write(rcfile, "# switch with exact version pins); it never builds or installs packages.\n")
      request.io.write(rcfile, "\n")
      request.io.write(rcfile, "# All pinned repositories are seeded at init so the large upstream\n")
      request.io.write(rcfile, "# default repository is never fetched.\n")
      request.io.write(rcfile, "repositories: [\n")
      local bk, bv = next(repos)
      while bk do
        request.io.write(rcfile, "  \"" .. bv.name .. "\" {\"" .. bv.url .. "\"}\n")
        bk, bv = next(repos, bk)
      end
      request.io.write(rcfile, "]\n")
      request.io.write(rcfile, "\n")
      request.io.write(rcfile, "# Nothing is built in this root, so no compiler switch is ever wanted\n")
      request.io.write(rcfile, "# and no default invariant should constrain switch creation.\n")
      request.io.write(rcfile, "default-compiler: []\n")
      request.io.write(rcfile, "default-invariant: []\n")
      request.io.write(rcfile, "\n")
      request.io.write(rcfile, "# Solve-only: no host tools (make, cc, curl, tar, unzip, bwrap) need to\n")
      request.io.write(rcfile, "# exist at init time, so a minimal container can run the solve.\n")
      request.io.write(rcfile, "required-tools: []\n")
      request.io.write(rcfile, "recommended-tools: []\n")
      request.io.write(rcfile, "\n")
      request.io.write(rcfile, "# Sandbox-free by construction: empty wrap commands mean no sandbox.sh\n")
      request.io.write(rcfile, "# is ever invoked (complements --disable-sandboxing on the init call).\n")
      request.io.write(rcfile, "wrap-build-commands: []\n")
      request.io.write(rcfile, "wrap-install-commands: []\n")
      request.io.write(rcfile, "wrap-remove-commands: []\n")
      request.io.write(rcfile, "\n")
      request.io.write(rcfile, "# Disable the host ocamlc probes. The opamrc grammar rejects an empty\n")
      request.io.write(rcfile, "# eval-variables list, but an empty command evaluates to nothing, which\n")
      request.io.write(rcfile, "# leaves each variable undefined: every host then looks like a host\n")
      request.io.write(rcfile, "# without an OCaml installation, so host state cannot leak into\n")
      request.io.write(rcfile, "# dependency filter evaluation and change the solve per machine.\n")
      request.io.write(rcfile, "eval-variables: [\n")
      request.io.write(rcfile, "  [sys-ocaml-version [] \"disabled for hermetic solving\"]\n")
      request.io.write(rcfile, "  [sys-ocaml-system [] \"disabled for hermetic solving\"]\n")
      request.io.write(rcfile, "  [sys-ocaml-arch [] \"disabled for hermetic solving\"]\n")
      request.io.write(rcfile, "  [sys-ocaml-cc [] \"disabled for hermetic solving\"]\n")
      request.io.write(rcfile, "  [sys-ocaml-libc [] \"disabled for hermetic solving\"]\n")
      request.io.write(rcfile, "]\n")
      request.io.flush(rcfile)
      local rcpath = request.io.realpath(rcfile)
      request.io.close(rcfile)
      table.insert(initargs, "--config=" .. rcpath)
    end
    CommonsLang_OCaml__Dk_OpamLock__1_0_0.run(request, opam, initargs, nil, false)
  end

  -- add repositories globally (ignore "already exists")
  local rk, rv = next(repos)
  while rk do
    CommonsLang_OCaml__Dk_OpamLock__1_0_0.run(request, opam, { "repository", "add", rv.name, rv.url, "--dont-select", "--yes" }, nil, 1)
    rk, rv = next(repos, rk)
  end
  -- add the generated constraints repository and bind it to the switch too. The
  -- repo name persists in a reused OPAMROOT but its sandbox path (and contents)
  -- change every run, and `opam repository add` will NOT refresh an existing
  -- name -- it keeps serving the previous run's cached (now-deleted) copy, so a
  -- freshly generated package reads back as "unknown package". Remove any stale
  -- registration from all scopes first, then add the current path.
  if csrepo_url then
    CommonsLang_OCaml__Dk_OpamLock__1_0_0.run(request, opam, { "repository", "remove", "dk-solve-constraints-repo", "--all", "--yes" }, nil, 1)
    CommonsLang_OCaml__Dk_OpamLock__1_0_0.run(request, opam, { "repository", "add", "dk-solve-constraints-repo", csrepo_url, "--dont-select", "--yes" }, nil, 1)
    table.insert(reponames, "dk-solve-constraints-repo")
  end

  -- create the empty switch bound to those repositories if it does not exist
  local swres = CommonsLang_OCaml__Dk_OpamLock__1_0_0.run(request, opam, { "switch", "list", "--short" }, nil, 1)
  local swlines = CommonsLang_OCaml__Dk_OpamLock__1_0_0.lines(swres.stdout)
  local have = false
  local sk, sv = next(swlines)
  while sk do if sv == switch then have = true end; sk, sv = next(swlines, sk) end
  if not have then
    -- Tolerate an already-installed switch. The list-based detection above can
    -- miss a switch that is genuinely present (an idempotent re-run over a
    -- persisted OPAMROOT), so create with allowfailure and accept only the
    -- "already ... installed switch" outcome; any other create failure is fatal.
    local cres = CommonsLang_OCaml__Dk_OpamLock__1_0_0.run(request, opam, { "switch", "create", switch, "--empty", "--repositories=" .. CommonsLang_OCaml__Dk_OpamLock__1_0_0.join(reponames, ","), "--yes" }, nil, 1)
    if cres.status ~= "exit" or cres.code ~= 0 then
      local se = (cres.stderr or "") .. (cres.stdout or "")
      if string.find(se, "already") == nil then
        assert(false, "could not create switch `" .. switch .. "`: " .. se)
      end
    end
  end

  -- Version pins are enforced by the generated constraints repository (added
  -- above), so the closure resolves against dk-solve-constraints instead of 193
  -- per-package `opam pin add` calls.
  if constraints_pkg then
    print("[opam-lock] version locks supplied by the " .. constraints_pkg .. " constraints repository")
  end

  -- remove pins for floated packages (may not be pinned; ignore failure). An
  -- ephemeral switch starts empty, so nothing is pinned to float -- skip the pass
  -- entirely rather than spend one opam call per float removing nothing.
  if fresh then
    print("[opam-lock] skipping float removals: the ephemeral switch has no pins to remove")
  else
    local fk, fv = next(floats)
    while fk do
      CommonsLang_OCaml__Dk_OpamLock__1_0_0.run(request, opam, { "pin", "remove", "--switch=" .. switch, "--no-action", "-y", fv }, nil, 1)
      fk, fv = next(floats, fk)
    end
  end

  -- Path-pin every local package opam finds in local_opam_dir. `opam pin add
  -- <dir>` (no package name) scans that directory's *.opam files and pins them
  -- all, so callers never enumerate the local packages by hand.
  if local_opam_dir then
    CommonsLang_OCaml__Dk_OpamLock__1_0_0.run(request, opam, { "pin", "add", "--switch=" .. switch, "-n", "-y", local_opam_dir }, nil, false)
  end

  -- The constraints package (or nil), the per-arch exclusion packages
  -- (arch -> package name) to add to the resolve, and the declared dependency
  -- repositories (name/url from the pin table) to record in the lock.
  return constraints_pkg, archpkgs, repos
end

-- Discover the switch's local packages: the ones pinned to a local directory
-- (opam pin kind "rsync"/"path"), as opposed to the version-pinned externals
-- from the pin table. `opam pin list` prints "<name>.<ver>  (state)  <kind>
-- <target>" per line; a package is local iff its kind is rsync/path. Returns a
-- list of bare package names.
function CommonsLang_OCaml__Dk_OpamLock__1_0_0.discover_locals(request, opam, switch)
  local r = CommonsLang_OCaml__Dk_OpamLock__1_0_0.run(request, opam, { "pin", "list", "--switch=" .. switch }, nil, 1)
  local out = {}
  local ls = CommonsLang_OCaml__Dk_OpamLock__1_0_0.lines(r.stdout)
  local lk, line = next(ls)
  while lk do
    local w = CommonsLang_OCaml__Dk_OpamLock__1_0_0.words(line)
    -- lua-ml (Lua 2.5) has no boolean type, so `true`/`false` are undefined
    -- (they read as nil). Use nil/1 as the false/true flag.
    local is_local = nil
    local wk, wv = next(w)
    while wk do
      if wv == "rsync" or wv == "path" then is_local = 1 end
      wk, wv = next(w, wk)
    end
    if is_local ~= nil and w[1] then
      local dot = CommonsLang_OCaml__Dk_OpamLock__1_0_0.first_dot(w[1])
      if dot then table.insert(out, string.sub(w[1], 1, dot - 1)) end
    end
    lk, line = next(ls, lk)
  end
  return out
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


-- Probe the byte size of a source archive with a HEAD request (curl -sIL,
-- following redirects; the LAST Content-Length wins). The dk bundle asset
-- schema requires `size`, so consumers that turn lock sources into bundle
-- assets need it pinned in the lock. Returns nil when curl is unavailable
-- or no Content-Length is reported; the lock field is then omitted.
function CommonsLang_OCaml__Dk_OpamLock__1_0_0.source_size(request, url)
  -- The UI capture spawns with an explicit program path (no PATH search on
  -- Windows CreateProcess), so a bare "curl" is not found. Windows always ships
  -- curl at System32; on Unix execvp resolves the bare name against PATH.
  local curlexe = "curl"
  if request.execution and request.execution.OSFamily == "windows" then
    curlexe = "C:\\Windows\\System32\\curl.exe"
  end
  local r = CommonsLang_OCaml__Dk_OpamLock__1_0_0.run(request, curlexe, { "-f", "-sIL", url }, nil, 1)
  if r.status ~= "exit" or r.code ~= 0 then return nil end
  local lns = CommonsLang_OCaml__Dk_OpamLock__1_0_0.lines(r.stdout)
  local size = nil
  local k, ln = next(lns)
  while k do
    local low = string.lower(ln)
    if string.sub(low, 1, 15) == "content-length:" then
      local digits = ""
      local i = 16
      local n = string.len(ln)
      local stopped = false
      while i <= n and not stopped do
        local c = string.sub(ln, i, i)
        if c >= "0" and c <= "9" then
          digits = digits .. c
        elseif digits ~= "" then
          stopped = true
        end
        i = i + 1
      end
      if digits ~= "" then size = tonumber(digits) end
    end
    k, ln = next(lns, k)
  end
  -- HEAD `Content-Length` is unreliable for some CDN-backed release assets: the
  -- redirect target may omit it, leaving only the 3xx `Content-Length: 0` and so
  -- a spurious size of 0 (which the build-time rule then rejects, or fetches as 0
  -- bytes). Fall back to a real GET that reports the true downloaded byte count.
  if size == nil or size == 0 then
    local nul = "/dev/null"
    if request.execution and request.execution.OSFamily == "windows" then nul = "NUL" end
    local g = CommonsLang_OCaml__Dk_OpamLock__1_0_0.run(request, curlexe, { "-f", "-sL", "-o", nul, "-w", "%{size_download}", url }, nil, 1)
    if g.status == "exit" and g.code == 0 then
      local n = tonumber(CommonsLang_OCaml__Dk_OpamLock__1_0_0.trim(g.stdout))
      if n ~= nil and n > 0 then size = n end
    end
  end
  return size
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
    -- On Windows execution hosts also fetch the MSYS2 tree and MinGit so
    -- the init bootstrap in setup_switch never installs an internal Cygwin.
    -- MSYS2 ships only Release.Windows_x86_64 (x86/arm64 Windows hosts run
    -- the x64 tree through WOW64/emulation), so its slot is pinned rather
    -- than resolved via Release.execution_abi; Git.MinGit has all three
    -- Windows slots.
    local dirs = { opam = "$(get-object CommonsLang_OCaml.Opam@2.5.1 -s Release.execution_abi -d :)" }
    if request.execution and request.execution.OSFamily == "windows" then
      dirs.msys2 = "$(get-object CommonsLang_OCaml.MSYS2@2026.6.11 -s Release.Windows_x86_64 -d :)"
      dirs.git = "$(get-object CommonsBase_Build.Git.MinGit@2.55.0 -s Release.execution_abi -d :)"
    end
    return {
      submit = {
        expressions = {
          directories = dirs
        },
        andthen = { continue_ = { state = "solve" } }
      }
    }
  end
  local opamdir = request.continued.opam
  local opamexe = CommonsLang_OCaml__Dk_OpamLock__1_0_0.trim(request.io.realpath(opamdir)) .. "/bin/opam"
  if request.execution and request.execution.OSFamily == "windows" then opamexe = opamexe .. ".exe" end
  -- Close EACH continued directory object: leaving one open fails the
  -- continuation finalizer (open continued file objects are leaks).
  request.io.close(opamdir)
  -- The Windows-only msys2/git continuations become the Unix-infrastructure
  -- locations that the init bootstrap passes to opam.
  local winlocs = nil
  if request.continued.msys2 then
    local msys2dir = request.continued.msys2
    local gitdir = request.continued.git
    winlocs = {
      msys2 = CommonsLang_OCaml__Dk_OpamLock__1_0_0.trim(request.io.realpath(msys2dir)),
      git = CommonsLang_OCaml__Dk_OpamLock__1_0_0.trim(request.io.realpath(gitdir)) .. "/cmd"
    }
    request.io.close(msys2dir)
    request.io.close(gitdir)
  end
  return CommonsLang_OCaml__Dk_OpamLock__1_0_0.do_solve(request, opamexe, winlocs)
end

-- Solve each requested slot with the `opam` program, capture per-package
-- metadata, and publish the lock via request.ui.writefile. `winlocs` is nil
-- (PATH-opam mode and non-Windows hosts) or the Windows Unix-infrastructure
-- roots { msys2 = DIR, git = DIR } for the hermetic init bootstrap.
function CommonsLang_OCaml__Dk_OpamLock__1_0_0.do_solve(request, opam, winlocs)
  local H = CommonsLang_OCaml__Dk_OpamLock__1_0_0
  -- Parameters (dk0 dialog CommonsLang_OCaml.Dk.OpamLock.Solve@1.0.0 key=val ...).
  -- Normally only roots[] and (on a fresh switch) local_opam_dir are given; the
  -- rest default for the single-project case:
  --   out=PATH            lock output           (default dk.opam-lock.jsonc)
  --   switch=NAME         opam switch to REUSE  (default: an ephemeral local
  --                       switch created empty in the sandbox and removed after
  --                       the solve; pass a name only for fast iterative re-solves)
  --   pins=PATH           pin table             (default dk-opam-pins.txt)
  --   local_opam_dir=DIR  dir of local *.opam   (pins the locals; omit only to
  --                       reuse a switch whose locals are already pinned)
  --   slots[]=SLOT ...    output slots          (default: the 7 DkML slots)
  --   locals[]=PKG ...    local package names   (default: auto-discovered as the
  --                       switch's path pins, i.e. every *.opam in local_opam_dir)
  --   roots[]=PKG ...     REQUIRED: the executable packages whose closures to
  --                       lock. Deliberately NOT defaulted to all locals: some
  --                       locals (DkZero_Web, MlFront_Codept) drag in large,
  --                       unrelated closures (js_of_ocaml, codept-lib, tezt).
  local out = request.user.out or "dk.opam-lock.jsonc"
  local pins = request.user.pins or "dk-opam-pins.txt"

  -- The opam switch is a THROWAWAY resolution context, never an install target:
  -- this rule only ever runs `opam list --resolve` (solve) + `opam show` (read
  -- metadata) against an EMPTY switch of pins, never `opam install`. opam has no
  -- switch-less solve -- the solver needs a switch's repositories, pins, and
  -- os/arch variables -- so one is created just for the solve. By default it is
  -- an ephemeral LOCAL switch inside the rule's sandbox: unique per run (no
  -- cross-project or cross-run pin contamination -> reproducible) and removed
  -- after the solve. A `switch=` override reuses a persistent NAMED switch for
  -- fast iterative re-solves, at the cost of pins accumulated across runs.
  local switch = request.user.switch
  local ephemeral = (switch == nil)
  if ephemeral then
    local anchor = assert(request.io.open("opam-solve.anchor", "w"),
      "could not open a sandbox anchor for the ephemeral opam switch")
    request.io.flush(anchor)
    -- Short name ("solve", not "opam-solve-switch"): the switch dir prefixes
    -- every path inside it, and Windows MAX_PATH is unforgiving in a deep sandbox.
    switch = H.dirname(H.trim(request.io.realpath(anchor))) .. "/solve"
    request.io.close(anchor)
  end
  local slots = request.user.slots or H.DKML_SLOTS
  assert(type(slots) == "table", "slots must be a table: 'slots[]=SLOT1' 'slots[]=SLOT2' ...")

  local switchargs = { "--switch=" .. switch }

  -- Set up the switch from the pin table before solving (idempotent): add the
  -- pinned repositories and the generated constraints repository, and -- when
  -- local_opam_dir is given -- path-pin every local package opam finds there.
  -- `ephemeral` skips the float pass, which only un-pins packages on a reused
  -- persistent switch. Returns the constraints meta-package plus the per-arch
  -- exclusion packages (arch -> name) to co-resolve.
  local constraints_pkg, archpkgs, repos_decl = H.setup_switch(request, opam, switch, pins, request.user.local_opam_dir, winlocs, ephemeral)

  -- Local package names: explicit override, else auto-discover the switch's path
  -- pins (packages pinned to a local dir, vs the version-pinned externals). Used
  -- to mark the lock's in-tree entries "local":"t".
  local locals_list = request.user.locals or H.discover_locals(request, opam, switch)
  local locals_set = H.set_from_list(locals_list)

  local roots = assert(request.user.roots,
    "please provide 'roots[]=PKG1' 'roots[]=PKG2' ... (the executable packages to lock)")
  assert(type(roots) == "table", "roots must be a table: 'roots[]=PKG1' 'roots[]=PKG2' ...")

  -- Co-resolve the constraints meta-package so its version conflicts apply to
  -- the closure; it is dropped from the solution below.
  local rootscsv = H.join(roots, ",")
  if constraints_pkg then rootscsv = rootscsv .. "," .. constraints_pkg end

  -- opam version, for non-authoritative provenance.
  local verres = CommonsLang_OCaml__Dk_OpamLock__1_0_0.run(request, opam, { "--version" }, nil, 1)
  local opamver = CommonsLang_OCaml__Dk_OpamLock__1_0_0.trim(verres.stdout)

  -- 1. Solve each requested slot. Package keys are '<name>.<version>'.
  local slot_solutions = {}   -- slot -> { opam_vars=..., solution={keys} }
  local all_keys = {}         -- key -> true (union across slots)
  local k, slot = next(slots)
  while k do
    print("[opam-lock] solving slot " .. slot)
    local vars = assert(CommonsLang_OCaml__Dk_OpamLock__1_0_0.SLOT_VARS[slot], "unknown slot `" .. slot .. "` (no OPAMVAR mapping)")
    local envmods = {}
    local vk, vv = next(vars)
    while vk do table.insert(envmods, "+OPAMVAR_" .. vk .. "=" .. vv); vk, vv = next(vars, vk) end

    -- Add this slot's arch-exclusion package (if any) so the arch-agnostic
    -- disjunctions resolve to the arch-matching side.
    local slotresolve = rootscsv
    local archpkg = archpkgs[vars.arch]
    if archpkg then slotresolve = slotresolve .. "," .. archpkg end

    local args = { "list", "--resolve=" .. slotresolve, "--columns=package", "--short" }
    local sk, sv = next(switchargs)
    while sk do table.insert(args, sv); sk, sv = next(switchargs, sk) end

    local r = CommonsLang_OCaml__Dk_OpamLock__1_0_0.run(request, opam, args, envmods, false)
    -- Drop the synthetic constraints/arch packages from the solution -- they
    -- carry only the conflicts and are not part of the locked closure.
    local keys = {}
    local rawkeys = CommonsLang_OCaml__Dk_OpamLock__1_0_0.lines(r.stdout)
    local rik, rikey = next(rawkeys)
    while rik do
      local dot = CommonsLang_OCaml__Dk_OpamLock__1_0_0.first_dot(rikey)
      local nm = rikey; if dot then nm = string.sub(rikey, 1, dot - 1) end
      if string.sub(nm, 1, 9) ~= "dk-solve-" then table.insert(keys, rikey) end
      rik, rikey = next(rawkeys, rik)
    end
    -- Canonicalise: opam lists the solution in resolution order, which differs
    -- between the version-pin and constraints-repo solves though the closure is
    -- the same. Sort so the lock is byte-stable across solve methods.
    keys = CommonsLang_OCaml__Dk_OpamLock__1_0_0.sort_str_array(keys)
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
  -- opam_show_all batches all keys into as few `opam show` calls as the
  -- command-line-length and same-name-per-chunk limits allow (usually one or
  -- two), replacing the ~6-calls-per-package sweep that dominated the solve.
  local capture_total = 0
  local ck2 = next(all_keys); while ck2 do capture_total = capture_total + 1; ck2 = next(all_keys, ck2) end
  print("[opam-lock] reading opam metadata for " .. capture_total .. " packages (batched opam show)")
  local keylist = {}
  local akl = next(all_keys)
  while akl do table.insert(keylist, akl); akl = next(all_keys, akl) end
  local meta = CommonsLang_OCaml__Dk_OpamLock__1_0_0.opam_show_all(request, opam, switchargs,
    { "url.src:", "url.checksum:", "depends:", "build:", "install:", "depopts:" }, keylist)
  local packages = {}
  ak = next(all_keys)
  while ak do
    local dot = CommonsLang_OCaml__Dk_OpamLock__1_0_0.first_dot(ak)
    local name = string.sub(ak, 1, dot - 1)
    local version = string.sub(ak, dot + 1)
    local m = meta[ak]; if m == nil then m = {} end

    local url = CommonsLang_OCaml__Dk_OpamLock__1_0_0.unquote(m["url.src:"] or "")
    local sums = CommonsLang_OCaml__Dk_OpamLock__1_0_0.checksums(m["url.checksum:"] or "")
    local depends_raw = m["depends:"] or ""
    local build_raw = m["build:"] or ""
    local install_raw = m["install:"] or ""

    -- direct dep names that are in the closure
    local depends = {}
    local depnames = CommonsLang_OCaml__Dk_OpamLock__1_0_0.top_level_quoted(depends_raw)
    local dk, dname = next(depnames)
    while dk do
      if name_in_closure[dname] and dname ~= name then table.insert(depends, dname) end
      dk, dname = next(depnames, dk)
    end
    -- Activated optional dependencies (depopts) become real build edges. A topkg
    -- package builds an optional sublibrary gated on `--with-X %{X:installed}%`;
    -- when the depopt X is in the solved closure (name_in_closure) opam installed
    -- it into the shared switch, so the sublibrary WAS compiled and a dependent
    -- that needs it must build after X and stage it. That edge is absent from the
    -- opam `depends:` formula, so add it here from `depopts:`. A real opam switch
    -- records this implicitly via install order. (e.g. fmt/uucp/uuidm -> cmdliner,
    -- logs -> fmt,cmdliner.) Everything downstream keys off `depends`.
    local depset = {}
    local si, sn = next(depends)
    while si do depset[sn] = true; si, sn = next(depends, si) end
    local depopts_raw = m["depopts:"] or ""
    local optnames = CommonsLang_OCaml__Dk_OpamLock__1_0_0.top_level_quoted(depopts_raw)
    local ok2, oname = next(optnames)
    while ok2 do
      if name_in_closure[oname] and oname ~= name and not depset[oname] then
        table.insert(depends, oname); depset[oname] = true
      end
      ok2, oname = next(optnames, ok2)
    end

    local is_local = locals_set[name] ~= nil
    local source
    if is_local or url == "" or next(sums) == nil then
      source = CommonsLang_OCaml__Dk_OpamLock__1_0_0.NULL   -- local pin, or a virtual/compiler package with no archive
    else
      -- Keep the upstream url (its basename carries the real archive extension,
      -- which the build-time rule needs for tar-type detection). Size is probed
      -- from opam's content-addressed cache first (a reliable Content-Length,
      -- byte-identical to the checksummed archive) and only falls back to the
      -- upstream url. The build-time rule can reconstruct the same cache URL from
      -- the sha256 for a reproducible fetch, so the lock need not store it.
      -- A dk bundle asset can only carry sha256/sha1/blake2b256. When opam offers
      -- none of those (older packages ship md5/sha512), compute a sha256 from the
      -- upstream archive (the same bytes the build-time fetch verifies) and add it
      -- so the package is expressible as a bundle.
      -- Prefer the opam CACHE bytes (stable, content-addressed) so the recorded
      -- sha256, the probed size, and the build-time fetch all refer to the same
      -- content. But a custom fork/pin is not mirrored in the opam cache: the
      -- cache URL 404s (curl -f fails), so fall back to the direct upstream URL
      -- and record source.incache=0 so the build fetches from the URL too.
      local incache = 1
      if CommonsLang_OCaml__Dk_OpamLock__1_0_0.has_bundle_checksum(sums) == 0 then
        local cu0 = CommonsLang_OCaml__Dk_OpamLock__1_0_0.cache_url(sums)
        -- "" not nil: lua-ml mis-binds `local x = nil` (it once no-op'd this rule)
        local computed = ""
        if cu0 ~= nil then computed = CommonsLang_OCaml__Dk_OpamLock__1_0_0.source_sha256(request, cu0) or "" end
        if computed == "" then
          computed = CommonsLang_OCaml__Dk_OpamLock__1_0_0.source_sha256(request, url) or ""
          if computed ~= "" then incache = 0 end
        end
        if computed ~= "" then table.insert(sums, "sha256=" .. computed) end
      end
      source = { url = url, checksums = sums }
      -- archive type for the build-time tar (the cache filename is a bare hash)
      source.archive = CommonsLang_OCaml__Dk_OpamLock__1_0_0.archive_type(url)
      -- The build defaults to the cache; record incache=0 only for direct sources.
      if incache == 0 then source.incache = 0 end
      -- size probed from the same URL the build fetches (cache, else direct)
      local sz = nil
      if incache == 1 then
        local cu = CommonsLang_OCaml__Dk_OpamLock__1_0_0.cache_url(sums)
        if cu ~= nil then sz = CommonsLang_OCaml__Dk_OpamLock__1_0_0.source_size(request, cu) end
      end
      if sz == nil then sz = CommonsLang_OCaml__Dk_OpamLock__1_0_0.source_size(request, url) end
      -- Only record a positive size. A real source archive is never 0 bytes; a
      -- 0 comes from a degenerate size probe (e.g. curl -sIL capturing only a
      -- 3xx redirect's `Content-Length: 0` when the final 2xx length did not come
      -- through). Recording size:0 makes the build fetch 0 bytes, so treat it as
      -- "unknown" (omit) exactly as when the probe returns nil.
      if sz ~= nil and sz > 0 then source.size = sz end
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

  -- 3. Record opam repositories for reproducibility from the pin table's `repo`
  -- declarations (not by parsing `opam repository list`): those are exactly the
  -- pinned dependency sources the solve resolved against, with the commit already
  -- in the url. Reading them from the pin table avoids capturing the developer's
  -- global repos (`default`, stray test repos) and the generated constraints
  -- repository (whose sandbox url changes every run and would break reproducibility).
  local repos = {}
  if repos_decl then
    local di = 1
    while repos_decl[di] ~= nil do
      local dv2 = repos_decl[di]
      table.insert(repos, { name = dv2.name, url = dv2.url, commit = request.user.repo_commit or CommonsLang_OCaml__Dk_OpamLock__1_0_0.NULL })
      di = di + 1
    end
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

  -- Tear down the ephemeral solve switch now that every package's metadata has
  -- been captured (nothing was installed; it only ever held pins as the
  -- resolution context). Best-effort so a teardown hiccup never loses the lock.
  if ephemeral then
    CommonsLang_OCaml__Dk_OpamLock__1_0_0.run(request, opam, { "switch", "remove", switch, "--yes" }, nil, 1)
  end

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

-- ---------------------------------------------------------------------------
-- GenerateDriver: lock -> driver values file
-- ---------------------------------------------------------------------------

-- Index of the first occurrence of the single character `ch` in `s`, or nil.
-- (string.find treats `.` as a pattern wildcard, so scan by byte instead.)
function CommonsLang_OCaml__Dk_OpamLock__1_0_0.indexof_char(s, ch)
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
function CommonsLang_OCaml__Dk_OpamLock__1_0_0.numstr(v)
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
function CommonsLang_OCaml__Dk_OpamLock__1_0_0.modsegment(name)
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
CommonsLang_OCaml__Dk_OpamLock__1_0_0.DKML_PROVIDED = {
  "ocaml", "ocaml-base-compiler", "ocaml-config", "ocaml-options-vanilla",
  "base-unix", "base-threads", "base-bigarray", "dune", "flexdll",
  "conf-mingw-w64-gcc-x86_64", "host-arch-x86_64", "host-arch-x86_32",
  "host-arch-arm64", "host-system-mingw", "host-system-other"
}

-- The 7 DkML slots; the default for GenerateDriver's slots[] parameter.
CommonsLang_OCaml__Dk_OpamLock__1_0_0.DKML_SLOTS = {
  "Release.Windows_x86_64", "Release.Windows_x86",
  "Release.Linux_x86_64", "Release.Linux_x86", "Release.Linux_arm64",
  "Release.Darwin_x86_64", "Release.Darwin_arm64"
}

-- Depth-first post-order walk of `name`'s dependencies in the lock, appending
-- each buildable package to `order` after its dependencies. `seen` is marked
-- before recursing (opam dependency graphs are acyclic, so no cycle check).
-- A dependency with neither a source nor the local mark (a virtual package
-- such as `seq`) is skipped; a dependency absent from the lock is an error.
function CommonsLang_OCaml__Dk_OpamLock__1_0_0.driver_visit(byname, provided, name, seen, order)
  local H = CommonsLang_OCaml__Dk_OpamLock__1_0_0
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
-- Parameters (dk0 dialog CommonsLang_OCaml.Dk.OpamLock.GenerateDriver@1.0.0):
--   lock=PATH          project-relative lock file (the Solve output)
--   out=PATH           project-relative driver values file to write
--   root=PKG           opam package whose closure is chained (built last,
--                      into the `built` directory)
--   formid=ID@VER      the driver form id (ex. CommonsBase_Dk.Dk0@2.4.2)
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
function uirules.GenerateDriver(command, request)
  local H = CommonsLang_OCaml__Dk_OpamLock__1_0_0
  if command == "ui" then
    print("CommonsLang_OCaml.Dk.OpamLock@1.0.0: driver written.")
    return
  end
  if command ~= "submit" then return end

  local lockpath = assert(request.user.lock, "please provide 'lock=PROJECT_RELATIVE_LOCK_PATH'")
  local out = assert(request.user.out, "please provide 'out=PROJECT_RELATIVE_DRIVER_PATH'")
  local root = assert(request.user.root, "please provide 'root=PKG'")
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

  local order = {}
  local seen = {}
  H.driver_visit(byname, provided, root, seen, order)
  assert(order[1] ~= nil, "root `" .. root .. "` has no buildable closure in the lock")

  -- Emit the driver as JSONC. Concatenate in index order (the module `join`
  -- iterates with next(), which scrambles array order).
  local nl = "\n"
  local body = "// Driver for the per-package opam build of `" .. root .. "`: run-functions the" .. nl
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
    .. "        \"sequential\": true," .. nl
    .. "        \"private\": [" .. nl
  local lines = {}
  local pi = 1
  while prelude ~= nil and prelude[pi] ~= nil do
    table.insert(lines, "          \"" .. prelude[pi] .. "\"")
    pi = pi + 1
  end
  local oi = 1
  while order[oi] ~= nil do
    local name = order[oi]
    local dir = "p" .. H.numstr(oi - 1)
    if name == root then dir = "built" end
    local rf = "          \"run-function " .. rulefn .. " -d " .. dir
      .. " modver=" .. pkgpath .. ".Pkg." .. H.modsegment(name) .. "@" .. version
      .. " pkg=" .. name
      .. " localsrc=" .. localsrc
      .. " locksrcpath=" .. locksrcpath
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
  body = body
    .. "        ]" .. nl
    .. "      }," .. nl
    .. "      \"function\": {" .. nl
    .. "        \"commands\": [" .. nl
    .. "          [" .. nl
    .. "            \"$(get-object CommonsBase_Std.Coreutils@0.8.0 -s ${SLOTNAME.Release.execution_abi} -m ./coreutils.exe -f coreutils.exe -e '*')\"," .. nl
    .. "            \"cp\", \"built/install.zip\", \"${SLOT.request}/install.zip\"" .. nl
    .. "          ]" .. nl
    .. "        ]" .. nl
    .. "      }," .. nl
    .. "      \"outputs\": { \"assets\": [ { \"slots\": [" .. slotlist .. "], \"paths\": [\"install.zip\"] } ] }" .. nl
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
