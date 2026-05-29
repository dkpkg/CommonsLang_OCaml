#!/bin/sh
set -eu

output_sed_file=$1
bash_bin_dir=$2

escaped=$bash_bin_dir
escaped=${escaped//\\/\\\\}
escaped=${escaped//&/\\&}
escaped=${escaped//|/\\|}

printf '%s\n' "s|PATH=/usr/bin:/bin|PATH=$escaped:/usr/bin:/bin|g" >"$output_sed_file"
