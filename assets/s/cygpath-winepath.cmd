@ECHO OFF
REM    Copyright 2026 Diskuv, Inc.
REM
REM    Licensed under the Apache License, Version 2.0 (the "License");
REM    you may not use this file except in compliance with the License.
REM    You may obtain a copy of the License at
REM
REM        http://www.apache.org/licenses/LICENSE-2.0
REM
REM    Unless required by applicable law or agreed to in writing, software
REM    distributed under the License is distributed on an "AS IS" BASIS,
REM    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
REM    See the License for the specific language governing permissions and
REM    limitations under the License.

REM This batch script is designed to run inside Wine during the `make` of
REM github.com/ocaml/ocaml, and at runtime when `ocamlopt` and other
REM OCaml tools are invoked.

SETLOCAL ENABLEDELAYEDEXPANSION
SETLOCAL ENABLEEXTENSIONS

REM Dump all arguments into C:\args.txt for debugging
IF "%DK_DEBUG_CYGPATH%"=="1" ECHO Arguments: %* >> C:\args.txt

SET OPTMODE=unix
SET OPTFILE=
SET OPTABS=
GOTO PARSE_ARGS

:USAGE
ECHO Usage: cygpath [-u] [-w] [-m] [-a] [-d] [-ad] [-f FILE|--file FILE] [PATH]...
EXIT /B 1

:PARSE_ARGS
IF "%~1"=="" GOTO ARGS_PARSED
IF "%~1"=="-u" (
    SET OPTMODE=unix
    SHIFT
    GOTO PARSE_ARGS
)
IF "%~1"=="-w" (
    SET OPTMODE=windows
    SHIFT
    GOTO PARSE_ARGS
)
IF "%~1"=="-m" (
    SET OPTMODE=mixed
    SHIFT
    GOTO PARSE_ARGS
)
IF "%~1"=="-d" (
    SET OPTMODE=dos
    SHIFT
    GOTO PARSE_ARGS
)
IF "%~1"=="-a" (
    SET OPTABS=1
    SHIFT
    GOTO PARSE_ARGS
)
IF "%~1"=="-ad" (
    SET OPTABS=1
    SET OPTMODE=dos
    SHIFT
    GOTO PARSE_ARGS
)
IF "%~1"=="-f" (
    IF "%~2"=="" (
        ECHO ERROR: Missing argument for -f
        GOTO USAGE
    )
    SET OPTFILE=%~2
    SHIFT
    SHIFT
    GOTO PARSE_ARGS
)
IF "%~1"=="--file" (
    IF "%~2"=="" (
        ECHO ERROR: Missing argument for --file
        GOTO USAGE
    )
    SET OPTFILE=%~2
    SHIFT
    SHIFT
    GOTO PARSE_ARGS
)

REM Assume all remaining arguments are paths to convert.
REM Multiple paths are allowed; loop through them and convert each one.
:PATH_LOOP
IF "%~1"=="" GOTO ARGS_PARSED
CALL :CONVERT_PATH "%~1"
SHIFT
GOTO PATH_LOOP

REM We are done if no --file.
:ARGS_PARSED
IF "%OPTFILE%"=="" EXIT /B 0

REM If file is `-` then read from stdin.
IF "%OPTFILE%"=="-" (
    REM Read each line from stdin and convert it. This allows piping paths into the script.
    FOR /F "tokens=*" %%A IN ('findstr "^"') DO (
        IF "%DK_DEBUG_CYGPATH%"=="1" ECHO stdin line: %%A >> C:\args.txt
        CALL :CONVERT_PATH "%%A"
    )
    EXIT /B 0
)

REM Read each line from the file and convert it. This allows batch processing of multiple paths.
FOR /F "usebackq delims=" %%A IN ("%OPTFILE%") DO (
    IF "%DK_DEBUG_CYGPATH%"=="1" ECHO file line: %%A >> C:\args.txt
    CALL :CONVERT_PATH "%%A"
)
EXIT /B 0

:CONVERT_PATH
IF "%OPTABS%"=="1" (
    SET "INPUT=%~f1"
) ELSE (
    SET INPUT=%~1
)
IF "%OPTMODE%"=="mixed" (
    CALL :CONVERT_TO_MIXED "%INPUT%"
) ELSE IF "%OPTMODE%"=="windows" (
    CALL :CONVERT_TO_WINDOWS "%INPUT%"
) ELSE IF "%OPTMODE%"=="dos" (
    CALL :CONVERT_TO_DOS "%INPUT%"
) ELSE (
    CALL :CONVERT_TO_UNIX "%INPUT%"
)
EXIT /B 0

:CONVERT_TO_MIXED
REM Search/replace backslashes with forward slashes.
SET INPUT=%~1
SET INPUT=!INPUT:\=/!
ECHO !INPUT!
IF "%DK_DEBUG_CYGPATH%"=="1" ECHO Mixed: !INPUT! >> C:\args.txt
EXIT /B 0

:CONVERT_TO_UNIX
REM This does not make sense. Windows programs should NOT see the Unix path.
ECHO ERROR: Unix path conversion not implemented
EXIT /B 1

:CONVERT_TO_WINDOWS
SET INPUT=%~1
FOR /F "usebackq delims=" %%A IN (`winepath --windows "%INPUT%" 2^>nul`) DO (
    ECHO %%A
)
IF ERRORLEVEL 1 (
    ECHO ERROR: Failed to convert path "%INPUT%" to Windows format
    EXIT /B 1
)
EXIT /B 0

:CONVERT_TO_DOS
SET INPUT=%~1
FOR /F "usebackq delims=" %%A IN (`winepath --short "%INPUT%" 2^>nul`) DO (
    ECHO %%A
)
IF ERRORLEVEL 1 (
    ECHO ERROR: Failed to convert path "%INPUT%" to DOS format
    EXIT /B 1
)
EXIT /B 0
