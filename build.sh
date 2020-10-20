#!/bin/bash

# Stop at any error, show all commands
set -ex


docker build --rm -t quay.io/pypa/${POLICY}_${PLATFORM}:${TRAVIS_COMMIT} -f docker/Dockerfile-${POLICY}_${PLATFORM} docker/
