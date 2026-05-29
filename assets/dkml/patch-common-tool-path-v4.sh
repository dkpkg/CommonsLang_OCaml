#!/bin/sh
set -eu

target_file=$1
bash_bin_dir=$2

case $bash_bin_dir in
  [A-Za-z]:*)
    drive=${bash_bin_dir:0:1}
    drive=${drive,,}
    rest=${bash_bin_dir:2}
    rest=${rest//\\//}
    bash_bin_dir=/cygdrive/$drive$rest
    ;;
esac

PATH="$bash_bin_dir:$PATH"
export PATH

escaped=$bash_bin_dir
escaped=${escaped//&/\\&}
escaped=${escaped//|/\\|}

sed -i "s|PATH=/usr/bin:/bin|PATH=$escaped:/usr/bin:/bin|g" "$target_file"
