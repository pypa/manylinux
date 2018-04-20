#!/bin/bash

docker/build_scripts/prefetch.sh openssl curl
docker -D build --rm -t example/manylinux1_i686 -f docker/Dockerfile-i686 docker/
docker -D build --rm -t example/manylinux1_x86_64 -f docker/Dockerfile-x86_64 docker/
docker system prune -f
