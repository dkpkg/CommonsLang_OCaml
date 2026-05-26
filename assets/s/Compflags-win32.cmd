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

REM POSIX shell script from OCaml 5.4.1:
REM case $1 in
REM   stdlib.cm[iox])
REM       echo ' -nopervasives -no-alias-deps -w -49' \
REM            ' -pp "$AWK -f ./expand_module_aliases.awk"';;
REM   # stdlib dependencies
REM   camlinternalFormatBasics*.cm[iox]) echo ' -nopervasives';;
REM   # end stdlib dependencies
REM   camlinternalOO.cmx) echo ' -inline 0 -afl-inst-ratio 0';;
REM   camlinternalLazy.cmx) echo ' -afl-inst-ratio 0';;
REM     # never instrument camlinternalOO or camlinternalLazy (PR#7725)
REM   stdlib__Buffer.cmx) echo ' -inline 3';;
REM                            # make sure add_char is inlined (PR#5872)
REM   stdlib__Buffer.cm[io]) echo ' -w +A';;
REM   camlinternalFormat.cm[io]) echo ' -w +A -w -fragile-match';;
REM   stdlib__Printf.cm[io]|stdlib__Format.cm[io]|stdlib__Scanf.cm[io])
REM       echo ' -w +A -w -fragile-match';;
REM   stdlib__Scanf.cmx) echo ' -inline 9';;
REM   *Labels.cmi) echo ' -pp "$AWK -f ./expand_module_aliases.awk"';;
REM   *Labels.cm[ox]) echo ' -nolabels -no-alias-deps';;
REM   stdlib__Float.cm[ox]) echo ' -nolabels -no-alias-deps';;
REM   stdlib__Oo.cmi) echo ' -no-principal';;
REM     # preserve structure sharing in Oo.copy (PR#9767)
REM   *) echo ' ';;
REM esac

REM Use findstr to match the patterns. Which means we have to write
REM the string to a file without a newline.
REM In Wine, not all findstr options are supported.
<NUL SET /P ="%1" > compflagsearch.txt

findstr /l "stdlib.cmi" compflagsearch.txt >nul
IF %ERRORLEVEL% EQU 0 (
    ECHO. -nopervasives -no-alias-deps -w -49  -pp "%AWK% -f ./expand_module_aliases.awk"
    GOTO :EOF
)
findstr /l "stdlib.cmo" compflagsearch.txt >nul
IF %ERRORLEVEL% EQU 0 (
    ECHO. -nopervasives -no-alias-deps -w -49  -pp "%AWK% -f ./expand_module_aliases.awk"
    GOTO :EOF
)
findstr /l "stdlib.cmx" compflagsearch.txt >nul
IF %ERRORLEVEL% EQU 0 (
    ECHO. -nopervasives -no-alias-deps -w -49  -pp "%AWK% -f ./expand_module_aliases.awk"
    GOTO :EOF
)
findstr "^camlinternalFormatBasics.*\.cmi" compflagsearch.txt >nul
IF %ERRORLEVEL% EQU 0 (
    ECHO. -nopervasives
    GOTO :EOF
)
findstr "^camlinternalFormatBasics.*\.cmo" compflagsearch.txt >nul
IF %ERRORLEVEL% EQU 0 (
    ECHO. -nopervasives
    GOTO :EOF
)
findstr "^camlinternalFormatBasics.*\.cmx" compflagsearch.txt >nul
IF %ERRORLEVEL% EQU 0 (
    ECHO. -nopervasives
    GOTO :EOF
)
findstr "^camlinternalOO\.cmx" compflagsearch.txt >nul
IF %ERRORLEVEL% EQU 0 (
    ECHO. -inline 0 -afl-inst-ratio 0
    GOTO :EOF
)
findstr "^camlinternalLazy\.cmx" compflagsearch.txt >nul
IF %ERRORLEVEL% EQU 0 (
    ECHO. -afl-inst-ratio 0
    GOTO :EOF
)
findstr "^stdlib__Buffer\.cmx" compflagsearch.txt >nul
IF %ERRORLEVEL% EQU 0 (
    ECHO. -inline 3
    GOTO :EOF
)
findstr "^stdlib__Buffer\.cmi" compflagsearch.txt >nul
IF %ERRORLEVEL% EQU 0 (
    ECHO. -w +A
    GOTO :EOF
)
findstr "^stdlib__Buffer\.cmo" compflagsearch.txt >nul
IF %ERRORLEVEL% EQU 0 (
    ECHO. -w +A
    GOTO :EOF
)
findstr "^camlinternalFormat\.cmi" compflagsearch.txt >nul
IF %ERRORLEVEL% EQU 0 (
    ECHO. -w +A -w -fragile-match
    GOTO :EOF
)
findstr "^camlinternalFormat\.cmo" compflagsearch.txt >nul
IF %ERRORLEVEL% EQU 0 (
    ECHO. -w +A -w -fragile-match
    GOTO :EOF
)
findstr "^stdlib__Printf\.cmi" compflagsearch.txt >nul
IF %ERRORLEVEL% EQU 0 (
    ECHO. -w +A -w -fragile-match
    GOTO :EOF
)
findstr "^stdlib__Printf\.cmo" compflagsearch.txt >nul
IF %ERRORLEVEL% EQU 0 (
    ECHO. -w +A -w -fragile-match
    GOTO :EOF
)
findstr "^stdlib__Format\.cmi" compflagsearch.txt >nul
IF %ERRORLEVEL% EQU 0 (
    ECHO. -w +A -w -fragile-match
    GOTO :EOF
)
findstr "^stdlib__Format\.cmo" compflagsearch.txt >nul
IF %ERRORLEVEL% EQU 0 (
    ECHO. -w +A -w -fragile-match
    GOTO :EOF
)
findstr "^stdlib__Scanf\.cmi" compflagsearch.txt >nul
IF %ERRORLEVEL% EQU 0 (
    ECHO. -w +A -w -fragile-match
    GOTO :EOF
)
findstr "^stdlib__Scanf\.cmo" compflagsearch.txt >nul
IF %ERRORLEVEL% EQU 0 (
    ECHO. -w +A -w -fragile-match
    GOTO :EOF
)
findstr "^stdlib__Scanf\.cmx" compflagsearch.txt >nul
IF %ERRORLEVEL% EQU 0 (
    ECHO. -inline 9
    GOTO :EOF
)
findstr ".*Labels\.cmi" compflagsearch.txt >nul
IF %ERRORLEVEL% EQU 0 (
    ECHO. -pp "%AWK% -f ./expand_module_aliases.awk"
    GOTO :EOF
)
findstr ".*Labels\.cmo" compflagsearch.txt >nul
IF %ERRORLEVEL% EQU 0 (
    ECHO. -nolabels -no-alias-deps
    GOTO :EOF
)
findstr ".*Labels\.cmx" compflagsearch.txt >nul
IF %ERRORLEVEL% EQU 0 (
    ECHO. -nolabels -no-alias-deps
    GOTO :EOF
)
findstr "^stdlib__Float\.cmo" compflagsearch.txt >nul
IF %ERRORLEVEL% EQU 0 (
    ECHO. -nolabels -no-alias-deps
    GOTO :EOF
)
findstr "^stdlib__Float\.cmx" compflagsearch.txt >nul
IF %ERRORLEVEL% EQU 0 (
    ECHO. -nolabels -no-alias-deps
    GOTO :EOF
)
findstr /l stdlib__Oo.cmi compflagsearch.txt >nul
IF %ERRORLEVEL% EQU 0 (
    ECHO. -no-principal
    GOTO :EOF
)

REM There is a space at the end of the line!
ECHO. 

:EOF
REM Clean up
DEL compflagsearch.txt
