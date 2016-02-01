#!/bin/bash
docker login -e noemail -u $QUAY_USERNAME -p $QUAY_PASSWORD quay.io
for tag in quay.io/pypa/manylinux1_i686 quay.io/pypa/manylinux1_x86_64; do
    docker tag ${tag}:${COMMIT} ${tag}:latest
    docker push ${tag}:latest
done
