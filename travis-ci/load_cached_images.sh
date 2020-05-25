#!/usr/bin/env bash
set -e -u -x -o pipefail
shopt -s nullglob
# shellcheck source=tags.sh
source "$(dirname "$0")"/tags.sh
ls -la "$HOME"/docker || true
for tag in "${tags[@]}"; do
    tag_hash=$(echo -n "$tag" | md5sum | awk '{print $1}')
    for image_path in "$HOME/docker/${tag_hash}_"*".tar.gz"; do
        docker load --input="$image_path" || rm -f "$image_path"
    done
done
