#!/bin/bash

# Stop at any error, show all commands
set -ex

docker/build_scripts/prefetch.sh openssl curl
docker build --rm -t quay.io/pypa/manylinux1_$PLATFORM:$TRAVIS_COMMIT -f docker/Dockerfile-$PLATFORM docker/
