#!/bin/bash

# Stop at any error, show all commands
set -ex

docker/build_scripts/prefetch.sh openssl curl
docker build --rm -t $REPO:$TRAVIS_COMMIT -f docker/Dockerfile-x86_64 docker/
docker system prune -f
