#!/bin/bash

set -euo pipefail

export TZ=UTC0

DRY_RUN=0
if [ "${1:-}" == "--dry-run" ]; then
  DRY_RUN=1
fi

set -x

TAG="quay.io/pypa/${POLICY}_${PLATFORM}"
COMMIT_DATE=$(git show -s --format=%cd --date=short "${COMMIT_SHA}")
if eval "$(git rev-parse --is-shallow-repository)"; then
  git fetch --unshallow
fi
BUILD_NUMBER=$(git rev-list "--since=${COMMIT_DATE}T00:00:00Z" --first-parent --count "${COMMIT_SHA}")
BUILD_ID=${COMMIT_DATE//-/.}-${BUILD_NUMBER}  # This should be a version like tag to allow dependabot updates

docker tag "${TAG}:${COMMIT_SHA}" "${TAG}:${BUILD_ID}"
docker tag "${TAG}:${COMMIT_SHA}" "${TAG}:latest"

set +x

if [ $DRY_RUN -eq 0 ]; then
  docker login -u "${QUAY_USERNAME}" -p "${QUAY_PASSWORD}" quay.io
  docker push "${TAG}:${BUILD_ID}"
  docker push "${TAG}:latest"
fi
