#!/bin/sh
set -eu

file=$1
needle='            18.*) autodetect_compiler_vsdev_CMAKEGENERATOR="Visual Studio 17 2022";;'

if grep -F "$needle" "$file" >/dev/null 2>&1; then
    exit 0
fi

tmp="$file.tmp"
awk '
{
    print
    if (!done && $0 == "            17.*) autodetect_compiler_vsdev_CMAKEGENERATOR=\"Visual Studio 17 2022\";;") {
        print "            18.*) autodetect_compiler_vsdev_CMAKEGENERATOR=\"Visual Studio 17 2022\";;"
        done = 1
    }
}
END {
    if (!done) {
        exit 1
    }
}
' "$file" > "$tmp"

mv "$tmp" "$file"
