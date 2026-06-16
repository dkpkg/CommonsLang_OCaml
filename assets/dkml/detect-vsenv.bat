@echo off
setlocal EnableExtensions EnableDelayedExpansion

@REM Uses VSWHERE to find the latest Visual Studio installation that has the C++ workload,
@REM and then outputs environment variables that are derived from the same sources as
@REM VsDevCmd.bat. The output is in the form of "KEY=VALUE" lines that can be parsed
@REM by a caller.
@REM
@REM Sample output
@REM -------------
@REM
@REM VCToolsVersion=14.44.35207
@REM VisualStudioVersion=17.0
@REM VSCMD_VER=17.14
@REM VSINSTALLDIR=Y:\VS\
@REM WindowsSDKVersion=10.0.26100.0\
@REM
@REM DKML_COMPILE_VS_CMAKEGENERATOR=Visual Studio 17 2022
@REM DKML_COMPILE_VS_DIR=Y:\VS
@REM DKML_COMPILE_VS_MSVSPREFERENCE=VS17.14
@REM DKML_COMPILE_VS_VCVARSVER=14.44
@REM DKML_COMPILE_VS_WINSDKVER=10.0.26100.0
@REM
@REM The first group of outputs mimic the environment variables set by Common7\Tools\VsDevCmd.bat.
@REM In particular, the trailing backslashes match the output of VsDevCmd.bat.
@REM
@REM Anomaly 1: VsDevCmd.bat defines VSCMD_VER as a three-part version number.
@REM dkml-runtime-common's crossplatform-functions.sh only needs the major and minor version
@REM to produce a VSDEV_MSVSPREFERENCE used to set a MSVS_PREFERENCE for
@REM https://github.com/metastack/msvs-tools#msvs-detect. The complexity of the third number
@REM of finding the third number is not required (yet).
@REM
@REM The second group of outputs are DkML-specific variables that are derived from the
@REM VSWHERE as well, but are formatted slightly differently for DkML's use.

set "VSWHERE_EXE=%VSWHERE%"
if not exist "%VSWHERE_EXE%" (
    echo Error: VSWHERE environment variable is not set to a valid path. 1>&2    
    exit /b 1
)

set "VSW_TMP=%TEMP%\\dkml-vswhere-%RANDOM%.txt"
"%VSWHERE_EXE%" -latest -version [16.0,18.0) -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath > "%VSW_TMP%" 2>nul
if exist "%VSW_TMP%" set /p INSTALLPATH=<"%VSW_TMP%"
del "%VSW_TMP%" >nul 2>nul
if not defined INSTALLPATH (
    echo Error: VSWHERE did not find a suitable Visual Studio installation. 1>&2
    exit /b 1
)

set "VSW_TMP=%TEMP%\\dkml-vswhere-%RANDOM%.txt"
"%VSWHERE_EXE%" -latest -version [16.0,18.0) -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationVersion > "%VSW_TMP%" 2>nul
if exist "%VSW_TMP%" set /p INSTALLVERSION=<"%VSW_TMP%"
del "%VSW_TMP%" >nul 2>nul
if not defined INSTALLVERSION (
    echo Error: VSWHERE did not find a suitable Visual Studio installation version. 1>&2
    exit /b 1
)

set "DKML_COMPILE_VS_DIR=%INSTALLPATH%"

set "VCTOOLSVERSION="
if exist "%INSTALLPATH%\VC\Tools\MSVC" (
    for /f "delims=" %%I in ('dir /b /ad /o-n "%INSTALLPATH%\VC\Tools\MSVC" 2^>nul') do if not defined VCTOOLSVERSION set "VCTOOLSVERSION=%%I"
)

set "WINDOWSSDKVERSION="
if exist "%ProgramFiles(x86)%\Windows Kits\10\Include" (
    for /f "delims=" %%I in ('dir /b /ad /o-n "%ProgramFiles(x86)%\Windows Kits\10\Include" 2^>nul') do if not defined WINDOWSSDKVERSION set "WINDOWSSDKVERSION=%%I"
)

set "VSMAJOR="
set "VSMINOR=0"
for /f "tokens=1,2 delims=." %%A in ("%INSTALLVERSION%") do (
    if not defined VSMAJOR set "VSMAJOR=%%A"
    if not "%%B"=="" set "VSMINOR=%%B"
)
if not defined VSMAJOR (
    echo Error: Failed to parse Visual Studio major version from "%INSTALLVERSION%". 1>&2
    exit /b 1
)

set "VISUALSTUDIOMAJOR=%VSMAJOR%"
set /a VSMAJOR_INT=%VSMAJOR% >nul 2>nul
if not errorlevel 1 if %VSMAJOR_INT% GTR 18 set "VISUALSTUDIOMAJOR=18"

echo VSINSTALLDIR=%INSTALLPATH%\
echo DKML_COMPILE_VS_DIR=%DKML_COMPILE_VS_DIR%
if defined VCTOOLSVERSION (
    echo VCToolsVersion=%VCTOOLSVERSION%
    for /f "tokens=1,2 delims=." %%A in ("%VCTOOLSVERSION%") do if not "%%A"=="" if not "%%B"=="" echo DKML_COMPILE_VS_VCVARSVER=%%A.%%B
)
if defined WINDOWSSDKVERSION (
    echo WindowsSDKVersion=%WINDOWSSDKVERSION%\
    echo DKML_COMPILE_VS_WINSDKVER=%WINDOWSSDKVERSION%
)
echo VSCMD_VER=%VSMAJOR%.%VSMINOR%
echo VisualStudioVersion=%VISUALSTUDIOMAJOR%.0
echo DKML_COMPILE_VS_MSVSPREFERENCE=VS%VSMAJOR%.%VSMINOR%

if "%VISUALSTUDIOMAJOR%"=="11" (
    echo DKML_COMPILE_VS_CMAKEGENERATOR=Visual Studio 11 2012
) else if "%VISUALSTUDIOMAJOR%"=="12" (
    echo DKML_COMPILE_VS_CMAKEGENERATOR=Visual Studio 13 2013
) else if "%VISUALSTUDIOMAJOR%"=="14" (
    echo DKML_COMPILE_VS_CMAKEGENERATOR=Visual Studio 14 2015
) else if "%VISUALSTUDIOMAJOR%"=="15" (
    echo DKML_COMPILE_VS_CMAKEGENERATOR=Visual Studio 15 2017
) else if "%VISUALSTUDIOMAJOR%"=="16" (
    echo DKML_COMPILE_VS_CMAKEGENERATOR=Visual Studio 16 2019
) else if "%VISUALSTUDIOMAJOR%"=="17" (
    echo DKML_COMPILE_VS_CMAKEGENERATOR=Visual Studio 17 2022
) else (
    echo DKML_COMPILE_VS_CMAKEGENERATOR=Visual Studio 18 2026
)

exit /b 0
