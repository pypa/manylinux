#!/bin/bash
tag="quay.io/pypa/manylinux2010_x86_64_centos6_no_vsyscall"
build_id=$(git show -s --format=%cd-%h --date=short $TRAVIS_COMMIT)

docker login -u $QUAY_USERNAME -p $QUAY_PASSWORD quay.io
docker tag ${tag}:latest ${tag}:${build_id}
docker push ${tag}:${build_id}
docker push ${tag}:latest
