#!/bin/bash
docker login -u $QUAY_USERNAME -p $QUAY_PASSWORD quay.io
tag="quay.io/pypa/manylinux2014_$PLATFORM"
docker tag ${tag}:${TRAVIS_COMMIT} ${tag}:latest
docker push ${tag}:latest
