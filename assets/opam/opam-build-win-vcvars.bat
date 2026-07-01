@echo off
setlocal EnableExtensions
@REM Activate the MSVC environment, then run the opam build under it.
@REM %1=vswhere.exe  %2=arch (x64/x86)  %3=opam-build-win.sh  %4=output bin dir
@REM %5=msvs-detect stub  %6=mccs glpk stub  %7=prefix  %8=menhir tar
set "VSW=%~1"
set "VSDIR="
for /f "usebackq delims=" %%I in (`"%VSW%" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do set "VSDIR=%%I"
if not defined VSDIR ( echo Error: no Visual Studio with VC tools found 1>&2 & exit /b 1 )
call "%VSDIR%\VC\Auxiliary\Build\vcvarsall.bat" %~2 >nul || ( echo Error: vcvarsall %~2 failed 1>&2 & exit /b 1 )
sh "%~3" "%~4" "%~5" "%~6" "%~7" "%~8"
exit /b %ERRORLEVEL%
