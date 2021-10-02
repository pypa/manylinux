#!/bin/bash

# Stop at any error, show all commands
set -ex

docker/build_scripts/prefetch.sh perl openssl curl cacert
docker build --rm -t quay.io/pypa/manylinux1_${PLATFORM}:${COMMIT_SHA} -f docker/Dockerfile-${PLATFORM} docker/
