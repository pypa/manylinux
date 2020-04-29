#!/usr/bin/env bash
set -e -u -x -o pipefail
shopt -s nullglob
# shellcheck source=tags.sh
source "$(dirname "$0")"/tags.sh
mkdir -p "$HOME"/docker
for tag in "${tags[@]}"; do
    image_id=$(docker images --format '{{.ID}}' "$tag" 2>/dev/null)
    if [[ -n "$image_id" ]]; then
        tag_hash=$(echo -n "$tag" | md5sum | awk '{print $1}')
        image_path="$HOME/docker/${tag_hash}_${image_id}.tar.gz"
        if [[ ! -e "$image_path" ]]; then
            for old_image_path in "$HOME/docker/${tag_hash}_"*".tar.gz"; do
                rm "$old_image_path"
            done
            docker save "$tag" | gzip -2 >"$image_path"
        fi
    fi
done
