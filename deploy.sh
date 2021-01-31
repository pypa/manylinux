#!/bin/bash
tag="quay.io/pypa/${POLICY}_${PLATFORM}"
build_id=$(git show -s --format=%cd-%h --date=short ${COMMIT_SHA})

docker login -u $QUAY_USERNAME -p $QUAY_PASSWORD quay.io
docker tag ${tag}:${COMMIT_SHA} ${tag}:${build_id}
docker tag ${tag}:${COMMIT_SHA} ${tag}:latest
docker push ${tag}:${build_id}
docker push ${tag}:latest
