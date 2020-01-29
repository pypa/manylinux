#!/bin/bash
tag="quay.io/pypa/manylinux1_$PLATFORM"
build_id=$(git show -s --format=%cd-%h --date=short $TRAVIS_COMMIT)

docker login -u $QUAY_USERNAME -p $QUAY_PASSWORD quay.io
docker tag ${tag}:${TRAVIS_COMMIT} ${tag}:${build_id}
docker tag ${tag}:${TRAVIS_COMMIT} ${tag}:latest
docker push ${tag}:${build_id}
docker push ${tag}:latest
