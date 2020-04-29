#!/bin/bash

# Stop at any error, show all commands
set -ex


if [ "$PLATFORM" == x86_64 ] && [ "$1" != glibc_skip ] || [ "$1" == glibc_only ]; then
    docker/glibc/build.sh 32
    docker/glibc/build.sh 64
    if [ "$1" == "glibc_only" ]; then
        exit 0
    fi
    docker/glibc/build.sh all
fi

docker build --rm -t "quay.io/pypa/manylinux2010_$PLATFORM:$TRAVIS_COMMIT" -f "docker/Dockerfile-$PLATFORM" docker/
