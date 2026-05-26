@echo off
setlocal
if not defined CONFIG_SHELL set "CONFIG_SHELL=sh"
"%CONFIG_SHELL%" "%~dp0cygpath" %*
