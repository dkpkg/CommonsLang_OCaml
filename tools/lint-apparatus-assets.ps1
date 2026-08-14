#Requires -Version 7
<#
Enforces the keep-latest-only asset policy documented in dk.u "## Assets":

  1. DISK       every dk.u `file=` asset exists with the declared byteSize and
                sha256 (`dir=` assets: existence only).
  2. SHARED     a path declared under more than one Apparatus version must
                carry identical (byteSize, sha256) everywhere.
  3. REFERENCE  every literal `get-asset CommonsLang_OCaml.Apparatus.<Name>@<V>
                -p <path>` in etc/dk/v resolves to an exact (name, V, path)
                declaration in dk.u.
  4. VARIANTS   exactly one assets/opam/build-locked-package*.sh and one
                assets/opam-lock/dk_opam_lock*.ml exist (no -vN / _suffix
                file-name variants reappear).
  5. LATEST     the highest Dk.OpamBuild@/Dk.OpamLock@ rule version fetches
                only the highest declared version of each Apparatus asset it
                references, and has a matching Export@<ver> run-function in
                every active dist/*.u (active list = the distscript entries of
                .github/workflows/distribute-0.1.yml).

Run locally from anywhere: pwsh tools/lint-apparatus-assets.ps1
CI runs it on every push (lint.yml) and gates distribute-0.1.yml.
`-SelfTest` exercises the checks against embedded fixtures instead of the
repository (proves the failure paths without breaking the tree).
#>
param(
  [switch]$SelfTest
)
$ErrorActionPreference = 'Stop'

function Get-ApparatusDeclarations {
  # Parses dk.u: returns list of @{Name; Version; Path; IsDir; ByteSize; Sha256; Line}
  param([string[]]$DkuLines)
  $decls = @()
  $section = $null
  for ($i = 0; $i -lt $DkuLines.Count; $i++) {
    $line = $DkuLines[$i]
    if ($line -match '^###\s+CommonsLang_OCaml\.Apparatus@([0-9][0-9.]*)\s*$') {
      $section = $Matches[1]
      continue
    }
    if ($line -match '^##\s') { $section = $null; continue }
    if ($null -eq $section) { continue }
    if ($line -match '^\s*%\s*unified\.asset\s*\{\s*name="([^"]+)"\s*,\s*(file|dir)="([^"]+)"\s*\}') {
      $name = $Matches[1]; $kind = $Matches[2]; $path = $Matches[3]
      $byteSize = $null; $sha256 = $null
      # The output block is the next non-blank line.
      for ($j = $i + 1; $j -lt $DkuLines.Count; $j++) {
        if ($DkuLines[$j] -match '^\s*$') { continue }
        if ($DkuLines[$j] -match '\\dk\.asset\(byteSize:\s*"(\d+)",\s*checksum:\s*\(sha256:\s*"([0-9a-f]{64})"\)\)') {
          $byteSize = [int64]$Matches[1]; $sha256 = $Matches[2]
        }
        break
      }
      $decls += [pscustomobject]@{
        Name = $name; Version = $section; Path = $path; IsDir = ($kind -eq 'dir')
        ByteSize = $byteSize; Sha256 = $sha256; Line = $i + 1
      }
    }
  }
  return $decls
}

function Get-AssetReferences {
  # Scans values files for literal get-asset references to CommonsLang_OCaml.Apparatus.*
  param([System.IO.FileInfo[]]$ValueFiles)
  $refs = @()
  foreach ($f in $ValueFiles) {
    $lineNo = 0
    foreach ($line in [System.IO.File]::ReadLines($f.FullName)) {
      $lineNo++
      foreach ($m in [regex]::Matches($line, 'get-asset\s+CommonsLang_OCaml\.Apparatus\.([A-Za-z0-9_]+)@([0-9][0-9.]*)\s+-p\s+(\S+)')) {
        $refs += [pscustomobject]@{
          File = $f.Name; Line = $lineNo
          Name = $m.Groups[1].Value; Version = $m.Groups[2].Value; Path = $m.Groups[3].Value
        }
      }
    }
  }
  return $refs
}

function Compare-DkVersion {
  param([string]$A, [string]$B)
  $pa = $A.Split('.') | ForEach-Object { [int]$_ }
  $pb = $B.Split('.') | ForEach-Object { [int]$_ }
  for ($i = 0; $i -lt [Math]::Max($pa.Count, $pb.Count); $i++) {
    $x = if ($i -lt $pa.Count) { $pa[$i] } else { 0 }
    $y = if ($i -lt $pb.Count) { $pb[$i] } else { 0 }
    if ($x -ne $y) { return ($x - $y) }
  }
  return 0
}

function Invoke-Lint {
  # Returns a list of failure strings (empty = pass).
  param(
    [string]$RepoRoot,
    [string]$WorkflowPath  # relative to RepoRoot
  )
  $failures = [System.Collections.Generic.List[string]]::new()
  $dku = Join-Path $RepoRoot 'dk.u'
  if (-not (Test-Path $dku)) { $failures.Add("dk.u not found at $dku"); return $failures }
  $dkuLines = Get-Content -LiteralPath $dku
  $decls = @(Get-ApparatusDeclarations -DkuLines $dkuLines)
  if ($decls.Count -eq 0) { $failures.Add('dk.u: no Apparatus asset declarations parsed (parser or file shape changed?)') }

  # 1. DISK
  foreach ($d in $decls) {
    $full = Join-Path $RepoRoot ($d.Path -replace '/', [System.IO.Path]::DirectorySeparatorChar)
    if ($d.IsDir) {
      if (-not (Test-Path $full -PathType Container)) {
        $failures.Add("DISK dk.u:$($d.Line) $($d.Name)@$($d.Version): directory `"$($d.Path)`" missing")
      }
      continue
    }
    if (-not (Test-Path $full -PathType Leaf)) {
      $failures.Add("DISK dk.u:$($d.Line) $($d.Name)@$($d.Version): file `"$($d.Path)`" missing")
      continue
    }
    if ($null -eq $d.Sha256) {
      $failures.Add("DISK dk.u:$($d.Line) $($d.Name)@$($d.Version): no \dk.asset(byteSize/sha256) output block")
      continue
    }
    $sz = (Get-Item -LiteralPath $full).Length
    if ($sz -ne $d.ByteSize) {
      $failures.Add("DISK dk.u:$($d.Line) $($d.Name)@$($d.Version): byteSize $($d.ByteSize) declared but `"$($d.Path)`" is $sz bytes")
    }
    $hash = (Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($hash -ne $d.Sha256) {
      $failures.Add("DISK dk.u:$($d.Line) $($d.Name)@$($d.Version): sha256 mismatch for `"$($d.Path)`" (declared $($d.Sha256), actual $hash)")
    }
  }

  # 2. SHARED PATH
  foreach ($group in ($decls | Where-Object { -not $_.IsDir } | Group-Object Path)) {
    $distinct = @($group.Group | Select-Object -Unique ByteSize, Sha256)
    if ($distinct.Count -gt 1) {
      $vers = ($group.Group | ForEach-Object { "$($_.Name)@$($_.Version)" }) -join ', '
      $failures.Add("SHARED path `"$($group.Name)`" declared with differing bytes by: $vers (one path must mean one byte-sequence at HEAD)")
    }
  }

  # 3. REFERENCE
  $valueFiles = @(Get-ChildItem -LiteralPath (Join-Path $RepoRoot 'etc/dk/v') -File -Recurse |
    Where-Object { $_.Name -match '\.values\.(lua|jsonc|json)$' })
  $refs = @(Get-AssetReferences -ValueFiles $valueFiles)
  foreach ($r in $refs) {
    $hit = $decls | Where-Object { $_.Name -eq $r.Name -and $_.Version -eq $r.Version -and $_.Path -eq $r.Path }
    if (-not $hit) {
      $failures.Add("REFERENCE $($r.File):$($r.Line): get-asset Apparatus.$($r.Name)@$($r.Version) -p $($r.Path) has no matching dk.u declaration")
    }
  }

  # 4. VARIANTS
  $variantChecks = @(
    @{ Glob = 'assets/opam/build-locked-package*.sh'; Expect = 'assets/opam/build-locked-package.sh' },
    @{ Glob = 'assets/opam-lock/dk_opam_lock*.ml';    Expect = 'assets/opam-lock/dk_opam_lock.ml' }
  )
  foreach ($vc in $variantChecks) {
    $found = @(Get-ChildItem -Path (Join-Path $RepoRoot $vc.Glob) -File -ErrorAction SilentlyContinue)
    if ($found.Count -ne 1) {
      $names = ($found | ForEach-Object Name) -join ', '
      $failures.Add("VARIANTS $($vc.Glob) must match exactly one file ($($vc.Expect)); found $($found.Count): $names")
    }
  }

  # 5. LATEST
  $ruleFamilies = @('Dk.OpamBuild', 'Dk.OpamLock')
  $activeDist = @()
  $wf = Join-Path $RepoRoot $WorkflowPath
  if (Test-Path $wf) {
    foreach ($line in (Get-Content -LiteralPath $wf)) {
      if ($line -match '^\s*distscript:\s*(\S+\.u)\s*$') { $activeDist += $Matches[1] }
    }
  } else {
    $failures.Add("LATEST workflow $WorkflowPath not found (cannot derive active dist scripts)")
  }
  foreach ($family in $ruleFamilies) {
    $familyFiles = @($valueFiles | Where-Object {
      $_.Name -eq "$family.values.lua" -or $_.Name -match ('^' + [regex]::Escape($family) + '@([0-9][0-9.]*)\.values\.lua$')
    })
    if ($familyFiles.Count -eq 0) { $failures.Add("LATEST no $family values.lua found under etc/dk/v"); continue }
    $withVer = $familyFiles | ForEach-Object {
      $v = if ($_.Name -match '@([0-9][0-9.]*)\.values\.lua$') { $Matches[1] } else { '0.0.0' }
      [pscustomobject]@{ File = $_; Version = $v }
    }
    # Pick the highest version numerically (string sort is wrong for 1.0.9 vs 1.0.16).
    $latest = $withVer[0]
    foreach ($cand in $withVer) {
      if ((Compare-DkVersion $cand.Version $latest.Version) -gt 0) { $latest = $cand }
    }
    # 5a: latest rule fetches only the highest declared version of each asset name
    $latestRefs = @(Get-AssetReferences -ValueFiles @($latest.File))
    foreach ($r in $latestRefs) {
      $declared = @($decls | Where-Object { $_.Name -eq $r.Name })
      if ($declared.Count -eq 0) { continue } # REFERENCE check already reports this
      $maxDecl = $declared[0]
      foreach ($cand in $declared) {
        if ((Compare-DkVersion $cand.Version $maxDecl.Version) -gt 0) { $maxDecl = $cand }
      }
      if ((Compare-DkVersion $r.Version $maxDecl.Version) -ne 0) {
        $failures.Add("LATEST $($latest.File.Name):$($r.Line): fetches Apparatus.$($r.Name)@$($r.Version) but the highest declaration is @$($maxDecl.Version) (a new rule version must not reuse a stale asset)")
      }
    }
    # 5b: every active dist script exercises the latest rule version's Export
    foreach ($ds in $activeDist) {
      $dsPath = Join-Path $RepoRoot $ds
      if (-not (Test-Path $dsPath)) {
        $failures.Add("LATEST active distscript $ds (from $WorkflowPath) does not exist")
        continue
      }
      $needle = "run-function CommonsLang_OCaml.$family.Export@$($latest.Version) "
      $hasIt = (Select-String -LiteralPath $dsPath -SimpleMatch $needle -Quiet)
      if (-not $hasIt) {
        $failures.Add("LATEST ${ds}: missing `"$needle`" self-test line for the current $family version")
      }
    }
  }

  return $failures
}

function Invoke-SelfTest {
  $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("clo-lint-selftest-" + [guid]::NewGuid().ToString('n'))
  $null = New-Item -ItemType Directory -Force -Path $tmp,
    (Join-Path $tmp 'assets/opam'), (Join-Path $tmp 'assets/opam-lock'),
    (Join-Path $tmp 'etc/dk/v'), (Join-Path $tmp 'dist'), (Join-Path $tmp '.github/workflows')
  try {
    # --- fixture content ---
    $wrapper = "#!/bin/sh`necho wrapper`n"
    $helper = "let () = print_endline `"helper`"`n"
    [System.IO.File]::WriteAllText((Join-Path $tmp 'assets/opam/build-locked-package.sh'), $wrapper)
    [System.IO.File]::WriteAllText((Join-Path $tmp 'assets/opam-lock/dk_opam_lock.ml'), $helper)
    $wrapperSha = (Get-FileHash -LiteralPath (Join-Path $tmp 'assets/opam/build-locked-package.sh') -Algorithm SHA256).Hash.ToLowerInvariant()
    $wrapperSz = (Get-Item -LiteralPath (Join-Path $tmp 'assets/opam/build-locked-package.sh')).Length
    $helperSha = (Get-FileHash -LiteralPath (Join-Path $tmp 'assets/opam-lock/dk_opam_lock.ml') -Algorithm SHA256).Hash.ToLowerInvariant()
    $helperSz = (Get-Item -LiteralPath (Join-Path $tmp 'assets/opam-lock/dk_opam_lock.ml')).Length
    $dku = @"
## Assets

### CommonsLang_OCaml.Apparatus@1.0.10

  % unified.asset { name="OpamBuildWrapper", file="assets/opam/build-locked-package.sh" }
  \dk.asset(byteSize: "$wrapperSz", checksum: (sha256: "$wrapperSha"))\;

  % unified.asset { name="OpamLockHelper", file="assets/opam-lock/dk_opam_lock.ml" }
  \dk.asset(byteSize: "$helperSz", checksum: (sha256: "$helperSha"))\;
"@
    [System.IO.File]::WriteAllText((Join-Path $tmp 'dk.u'), $dku)
    $buildLua = @'
local M = { id = "CommonsLang_OCaml.Dk.OpamBuild@1.0.16" }
  local wrapperfetch = "$(get-asset CommonsLang_OCaml.Apparatus.OpamBuildWrapper@1.0.10 -p assets/opam/build-locked-package.sh -f build-wrapper.sh)"
'@
    [System.IO.File]::WriteAllText((Join-Path $tmp 'etc/dk/v/Dk.OpamBuild@1.0.16.values.lua'), $buildLua)
    $lockLua = @'
local M = { id = "CommonsLang_OCaml.Dk.OpamLock@1.1.6" }
      helper = "$(get-asset CommonsLang_OCaml.Apparatus.OpamLockHelper@1.0.10 -p assets/opam-lock/dk_opam_lock.ml -f dk_opam_lock.ml)",
'@
    [System.IO.File]::WriteAllText((Join-Path $tmp 'etc/dk/v/Dk.OpamLock@1.1.6.values.lua'), $lockLua)
    $distU = @'
## Dk.OpamLock

  $ run-function CommonsLang_OCaml.Dk.OpamLock.Export@1.1.6 -f ${RUNTIME}/OpamLock.Export-1.1.6.zip
  \test(pass)

## Dk.OpamBuild

  $ run-function CommonsLang_OCaml.Dk.OpamBuild.Export@1.0.16 -f ${RUNTIME}/OpamBuild.Export-1.0.16.zip
  \test(pass)
'@
    [System.IO.File]::WriteAllText((Join-Path $tmp 'dist/Test_abi.u'), $distU)
    $wfYml = @'
jobs:
  distribute:
    strategy:
      matrix:
        include:
          - abi: Test_abi
            distscript: dist/Test_abi.u
'@
    [System.IO.File]::WriteAllText((Join-Path $tmp '.github/workflows/distribute-0.1.yml'), $wfYml)

    function Assert-Case {
      param([string]$CaseName, [string[]]$Failures, [int]$ExpectedCount, [string]$MustMatch = $null)
      $ok = ($Failures.Count -eq $ExpectedCount)
      if ($ok -and $MustMatch) { $ok = [bool]($Failures | Where-Object { $_ -like "*$MustMatch*" }) }
      if ($ok) {
        Write-Host "selftest PASS: $CaseName"
      } else {
        Write-Host "selftest FAIL: $CaseName (got $($Failures.Count) failure(s): $($Failures -join ' | '))"
        $script:selfTestFailed = $true
      }
    }
    $script:selfTestFailed = $false

    # Case 1: pristine fixture passes
    $r = @(Invoke-Lint -RepoRoot $tmp -WorkflowPath '.github/workflows/distribute-0.1.yml')
    Assert-Case 'pristine fixture passes' $r 0

    # Case 2: flipped content -> DISK sha256 mismatch
    [System.IO.File]::WriteAllText((Join-Path $tmp 'assets/opam/build-locked-package.sh'), $wrapper + "# edited`n")
    $r = @(Invoke-Lint -RepoRoot $tmp -WorkflowPath '.github/workflows/distribute-0.1.yml')
    Assert-Case 'in-place edit without dk.u bump fails DISK' $r 2 'sha256 mismatch'
    [System.IO.File]::WriteAllText((Join-Path $tmp 'assets/opam/build-locked-package.sh'), $wrapper)

    # Case 3: reference to an undeclared version -> REFERENCE
    [System.IO.File]::WriteAllText((Join-Path $tmp 'etc/dk/v/Dk.OpamBuild@1.0.16.values.lua'),
      $buildLua.Replace('OpamBuildWrapper@1.0.10', 'OpamBuildWrapper@1.0.9'))
    $r = @(Invoke-Lint -RepoRoot $tmp -WorkflowPath '.github/workflows/distribute-0.1.yml')
    Assert-Case 'stale get-asset version fails REFERENCE+LATEST' $r 2 'no matching dk.u declaration'
    [System.IO.File]::WriteAllText((Join-Path $tmp 'etc/dk/v/Dk.OpamBuild@1.0.16.values.lua'), $buildLua)

    # Case 4: a -vN variant file reappears -> VARIANTS
    [System.IO.File]::WriteAllText((Join-Path $tmp 'assets/opam/build-locked-package-v7.sh'), "#!/bin/sh`n")
    $r = @(Invoke-Lint -RepoRoot $tmp -WorkflowPath '.github/workflows/distribute-0.1.yml')
    Assert-Case 'variant file reappearance fails VARIANTS' $r 1 'must match exactly one file'
    Remove-Item -LiteralPath (Join-Path $tmp 'assets/opam/build-locked-package-v7.sh')

    # Case 5: new rule version reusing an older Apparatus when a newer one exists -> LATEST
    $dku2 = $dku + @"

### CommonsLang_OCaml.Apparatus@1.0.11

  % unified.asset { name="OpamBuildWrapper", file="assets/opam/build-locked-package.sh" }
  \dk.asset(byteSize: "$wrapperSz", checksum: (sha256: "$wrapperSha"))\;
"@
    [System.IO.File]::WriteAllText((Join-Path $tmp 'dk.u'), $dku2)
    $r = @(Invoke-Lint -RepoRoot $tmp -WorkflowPath '.github/workflows/distribute-0.1.yml')
    Assert-Case 'latest rule fetching stale asset version fails LATEST' $r 1 'must not reuse a stale asset'
    [System.IO.File]::WriteAllText((Join-Path $tmp 'dk.u'), $dku)

    # Case 6: dist script missing the current Export line -> LATEST
    [System.IO.File]::WriteAllText((Join-Path $tmp 'dist/Test_abi.u'), $distU.Replace('Export@1.0.16', 'Export@1.0.15'))
    $r = @(Invoke-Lint -RepoRoot $tmp -WorkflowPath '.github/workflows/distribute-0.1.yml')
    Assert-Case 'dist missing current Export fails LATEST' $r 1 'self-test line'
    [System.IO.File]::WriteAllText((Join-Path $tmp 'dist/Test_abi.u'), $distU)

    if ($script:selfTestFailed) { return 1 }
    return 0
  } finally {
    Remove-Item -Recurse -Force -LiteralPath $tmp -ErrorAction SilentlyContinue
  }
}

if ($SelfTest) {
  exit (Invoke-SelfTest)
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$failures = @(Invoke-Lint -RepoRoot $repoRoot -WorkflowPath '.github/workflows/distribute-0.1.yml')
if ($failures.Count -gt 0) {
  foreach ($f in $failures) { Write-Host "lint FAIL: $f" }
  Write-Host "lint-apparatus-assets: $($failures.Count) failure(s)"
  exit 1
}
Write-Host 'lint-apparatus-assets: OK'
exit 0
