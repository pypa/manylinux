#!/bin/bash

# Stop at any error, show all commands
set -ex

docker/build_scripts/prefetch.sh openssl curl
if [ $PLATFORM == x86_64 ]; then
    docker build --rm -t quay.io/pypa/manylinux2010_centos-6.9-no-vsyscall -f docker/glibc/Dockerfile docker/glibc/
fi
docker build --rm -t quay.io/pypa/manylinux2010_$PLATFORM:$TRAVIS_COMMIT -f docker/Dockerfile-$PLATFORM docker/
docker system prune -f
