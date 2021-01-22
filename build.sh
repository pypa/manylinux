#!/bin/bash

# Stop at any error, show all commands
set -ex


docker build --rm -t "ryanhuanli/manylinux2010" -f "docker/Dockerfile-x86_64" docker/
docker build --rm -t "ryanhuanli/manylinux2010-rust-python" -f "Dockerfile" .
