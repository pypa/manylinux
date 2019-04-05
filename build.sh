#!/bin/bash

# Stop at any error, show all commands
set -ex

docker/build_scripts/prefetch.sh openssl curl
if [ $PLATFORM == x86_64 ]; then
    # Output something every 10 minutes or Travis kills the job
    while sleep 9m; do echo -n -e " \b"; done &
    docker build --rm -t quay.io/pypa/manylinux2010_centos-6-no-vsyscall -f docker/glibc/Dockerfile docker/glibc/
    # Killing background sleep loop
    kill %1
fi
docker build --rm -t quay.io/pypa/manylinux2010_$PLATFORM:$TRAVIS_COMMIT -f docker/Dockerfile-$PLATFORM docker/
