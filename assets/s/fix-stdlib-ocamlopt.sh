#!/bin/sh
set -eu

file=$1
tmp="${file}.new"

awk '
BEGIN { d = sprintf("%c", 36) }
/^OPTCOMPILER=/ {
  print "OPTCOMPILER=" d "(ROOTDIR)/ocamlopt" d "(EXE)"
  next
}
{ print }
' "$file" >"$tmp"

mv "$tmp" "$file"
