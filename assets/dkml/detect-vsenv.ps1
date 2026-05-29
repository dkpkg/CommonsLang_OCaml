$ErrorActionPreference = 'Stop'

$vswhereCandidates = @(
    'C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe',
    'C:\Program Files\Microsoft Visual Studio\Installer\vswhere.exe'
)

$vswhere = $vswhereCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $vswhere) {
    exit 0
}

$installJson = & $vswhere -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -format json
if (-not $installJson) {
    exit 0
}

$installs = $installJson | ConvertFrom-Json
if ($installs -isnot [System.Array]) {
    $installs = @($installs)
}

$selected = $installs |
    Sort-Object { [version]$_.installationVersion } -Descending |
    Where-Object { $_.installationVersion.Split('.')[0] -eq '17' } |
    Select-Object -First 1

if (-not $selected) {
    $selected = $installs |
        Sort-Object { [version]$_.installationVersion } -Descending |
        Select-Object -First 1
}

if (-not $selected) {
    exit 0
}

$installPath = $selected.installationPath.Trim()
$installVersion = $selected.installationVersion.Trim()
$installPathUnix = $installPath -replace '\\', '/'
if ($installPathUnix -match '^(?<drive>[A-Za-z]):(?<rest>/.*)$') {
    $installPathUnix = "/cygdrive/$($matches.drive.ToLower())$($matches.rest)"
}

$msvcDir = Join-Path $installPath 'VC\Tools\MSVC'
$vcToolsVersion = ''
if (Test-Path $msvcDir) {
    $vcToolsVersion = Get-ChildItem $msvcDir -Directory |
        Sort-Object Name -Descending |
        Select-Object -First 1 -ExpandProperty Name
}

$sdkDir = 'C:\Program Files (x86)\Windows Kits\10\Include'
$windowsSdkVersion = ''
if (Test-Path $sdkDir) {
    $windowsSdkVersion = Get-ChildItem $sdkDir -Directory |
        Sort-Object Name -Descending |
        Select-Object -First 1 -ExpandProperty Name
}

$parts = $installVersion.Split('.')
$vsMajor = if ($parts.Length -ge 1) { $parts[0] } else { '' }
$vsMinor = if ($parts.Length -ge 2) { $parts[1] } else { '0' }
$visualStudioMajor = $vsMajor
if ($vsMajor) {
    try {
        if ([int]$vsMajor -gt 17) {
            $visualStudioMajor = '17'
        }
    } catch {
    }
}

if ($installPath) {
    "VSINSTALLDIR=$installPath\"
    "DKML_COMPILE_VS_DIR=$installPathUnix"
}
if ($vcToolsVersion) {
    "VCToolsVersion=$vcToolsVersion"
    $vcvarsParts = $vcToolsVersion.Split('.')
    if ($vcvarsParts.Length -ge 2) {
        "DKML_COMPILE_VS_VCVARSVER=$($vcvarsParts[0]).$($vcvarsParts[1])"
    }
}
if ($windowsSdkVersion) {
    "WindowsSDKVersion=$windowsSdkVersion\"
    "DKML_COMPILE_VS_WINSDKVER=$windowsSdkVersion"
}
if ($vsMajor) {
    "VSCMD_VER=$vsMajor.$vsMinor"
    "VisualStudioVersion=$visualStudioMajor.0"
    "DKML_COMPILE_VS_MSVSPREFERENCE=VS$vsMajor.$vsMinor"
}

if ($visualStudioMajor) {
    switch ($visualStudioMajor) {
        '11' { 'DKML_COMPILE_VS_CMAKEGENERATOR=Visual Studio 11 2012' }
        '12' { 'DKML_COMPILE_VS_CMAKEGENERATOR=Visual Studio 13 2013' }
        '14' { 'DKML_COMPILE_VS_CMAKEGENERATOR=Visual Studio 14 2015' }
        '15' { 'DKML_COMPILE_VS_CMAKEGENERATOR=Visual Studio 15 2017' }
        '16' { 'DKML_COMPILE_VS_CMAKEGENERATOR=Visual Studio 16 2019' }
        default { 'DKML_COMPILE_VS_CMAKEGENERATOR=Visual Studio 17 2022' }
    }
}
