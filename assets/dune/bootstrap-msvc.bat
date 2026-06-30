@echo off
setlocal EnableExtensions
@REM Bootstrap Dune off the DkML MSVC OCaml 4.14.3.
@REM Run from the build root which contains s\ (the extracted Dune source).
@REM DkML's ocaml + flexlink are expected on PATH (provided by a dk0 envmod).
@REM Args: %1=vswhere.exe  %2=arch (x64 or x86)  %3=output bin dir
set "ROOT=%CD%"
set "VSW=%~1"
set "ARCH=%~2"
set "OUTDIR=%~3"
if not exist "%VSW%" ( echo Error: vswhere not found at "%VSW%" 1>&2 & exit /b 1 )
set "VSDIR="
for /f "usebackq delims=" %%I in (`"%VSW%" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do set "VSDIR=%%I"
if not defined VSDIR ( echo Error: no Visual Studio with VC tools found 1>&2 & exit /b 1 )
call "%VSDIR%\VC\Auxiliary\Build\vcvarsall.bat" %ARCH% >nul || ( echo Error: vcvarsall %ARCH% failed 1>&2 & exit /b 1 )
cd /d "%ROOT%\s" || ( echo Error: missing source dir "%ROOT%\s" 1>&2 & exit /b 1 )
ocaml boot/bootstrap.ml || ( echo Error: dune bootstrap failed 1>&2 & exit /b 1 )
if not exist "_boot\dune.exe" ( echo Error: _boot\dune.exe not produced 1>&2 & exit /b 1 )
if not exist "%OUTDIR%" mkdir "%OUTDIR%"
copy /y "_boot\dune.exe" "%OUTDIR%\dune.exe" >nul || ( echo Error: copy to "%OUTDIR%" failed 1>&2 & exit /b 1 )
echo Dune bootstrap OK: "%OUTDIR%\dune.exe"
exit /b 0
