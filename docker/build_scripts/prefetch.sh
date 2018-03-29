#!/bin/bash
# Prefetch tarballs so they don't need to be fetched in the container (which has
# very old tools)
#
# usage: prefetch.sh <output_dir> [name ...]
set -ex

MY_DIR=$(dirname "${BASH_SOURCE[0]}")
. $MY_DIR/build_env.sh
. $MY_DIR/build_utils.sh

dir=$1
check_var ${dir}
shift

[ -d "$dir" ] || mkdir "$dir"

for name in "$@"; do
    name=$(echo $name | tr '[:lower:]' '[:upper:]')
    root=${name}_ROOT
    ext=${name}_EXTENSION
    url=${name}_DOWNLOAD_URL
    file=${!root}${!ext:-.tar.gz}
    fetch_source $file ${!url} $dir
done
