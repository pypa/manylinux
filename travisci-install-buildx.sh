#!/bin/bash

# This script is used to install docker buildx in travis-ci

# Stop at any error, show all commands
set -exuo pipefail

BUILDX_MACHINE=$(uname -m)
if [ ${BUILDX_MACHINE} == "x86_64" ]; then
	BUILDX_MACHINE=amd64
elif [ ${BUILDX_MACHINE} == "aarch64" ]; then
	BUILDX_MACHINE=arm64
fi

mkdir -vp ~/.docker/cli-plugins/
curl -sSL "https://github.com/docker/buildx/releases/download/v0.5.1/buildx-v0.5.1.linux-${BUILDX_MACHINE}" > ~/.docker/cli-plugins/docker-buildx
chmod a+x ~/.docker/cli-plugins/docker-buildx
docker buildx version
docker buildx create --name builder-manylinux --driver docker-container --use
docker buildx inspect --bootstrap --builder builder-manylinux
