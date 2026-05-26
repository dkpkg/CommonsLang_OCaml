#!/bin/sh
set -eu

file=$1
tmp="${file}.new"

awk '
BEGIN { d = sprintf("%c", 36) }
/^INSTALL \?= (\.\/)?build-aux\/install-sh -c -p$/ {
  print "INSTALL ?= sh.exe " d "(ROOTDIR)/build-aux/install-sh -c"
  next
}
{ print }
' "$file" >"$tmp"

mv "$tmp" "$file"
