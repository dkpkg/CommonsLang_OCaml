@ECHO OFF
REM The default MKLIB in Makefile.config is:
REM   rm -f $(1) && *-w64-mingw32-ar rc $(1) $(2)
REM But with no shell, the "&&" is not supported. In fact, all arguments are
REM passed to `rm`.
SETLOCAL ENABLEDELAYEDEXPANSION

REM This script does both the "rm" and "ar" steps, and is used as MKLIB in Makefile.config.

REM %1 is the output file. All the rest are the input files

REM Remove the output file first, if it exists.
REM Since the output file may have forward slashes (/) which will cause
REM Command Prompt to fail and say "File not found", we use coreutils `rm`.
IF EXIST %1 (
    rm -f %1
)

REM Create the archive with ar
i686-w64-mingw32-ar rc %*
IF ERRORLEVEL 1 (
    ECHO Failed to create archive %1
    EXIT /B 1
)