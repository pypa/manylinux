#!/bin/bash

# Stop at any error, show all commands
set -exuo pipefail

if [ "${MANYLINUX_BUILD_FRONTEND:-}" == "" ]; then
	MANYLINUX_BUILD_FRONTEND="docker-buildx"
fi

# Export variable needed by 'docker build --build-arg'
export POLICY
export PLATFORM

# get docker default multiarch image prefix for PLATFORM
case "${PLATFORM}" in
	x86_64) GOARCH="amd64";;
	i686) GOARCH="386";;
	aarch64) GOARCH="arm64";;
	ppc64le) GOARCH="ppc64le";;
	s390x) GOARCH="s390x";;
	armv7l) GOARCH="arm/v7";;
	*) echo "Unsupported platform: '${PLATFORM}'"; exit 1;;
esac

# setup BASEIMAGE and its specific properties
if [ "${POLICY}" == "manylinux2014" ]; then
	BASEIMAGE="quay.io/pypa/manylinux2014_base:2024.11.03-3"
	DEVTOOLSET_ROOTPATH="/opt/rh/devtoolset-10/root"
	PREPEND_PATH="${DEVTOOLSET_ROOTPATH}/usr/bin:"
	if [ "${PLATFORM}" == "i686" ]; then
		LD_LIBRARY_PATH_ARG="${DEVTOOLSET_ROOTPATH}/usr/lib:${DEVTOOLSET_ROOTPATH}/usr/lib/dyninst"
	else
		LD_LIBRARY_PATH_ARG="${DEVTOOLSET_ROOTPATH}/usr/lib64:${DEVTOOLSET_ROOTPATH}/usr/lib:${DEVTOOLSET_ROOTPATH}/usr/lib64/dyninst:${DEVTOOLSET_ROOTPATH}/usr/lib/dyninst:/usr/local/lib64"
	fi
elif [ "${POLICY}" == "manylinux_2_28" ]; then
	BASEIMAGE="almalinux:8"
	DEVTOOLSET_ROOTPATH="/opt/rh/gcc-toolset-14/root"
	PREPEND_PATH="${DEVTOOLSET_ROOTPATH}/usr/bin:"
	LD_LIBRARY_PATH_ARG="${DEVTOOLSET_ROOTPATH}/usr/lib64:${DEVTOOLSET_ROOTPATH}/usr/lib:${DEVTOOLSET_ROOTPATH}/usr/lib64/dyninst:${DEVTOOLSET_ROOTPATH}/usr/lib/dyninst"
elif [ "${POLICY}" == "manylinux_2_31" ]; then
	BASEIMAGE="ubuntu:20.04"
	DEVTOOLSET_ROOTPATH=
	PREPEND_PATH=
	LD_LIBRARY_PATH_ARG=
elif [ "${POLICY}" == "manylinux_2_34" ]; then
	BASEIMAGE="almalinux:9"
	DEVTOOLSET_ROOTPATH="/opt/rh/gcc-toolset-14/root"
	PREPEND_PATH="/usr/local/bin:${DEVTOOLSET_ROOTPATH}/usr/bin:"
	LD_LIBRARY_PATH_ARG="${DEVTOOLSET_ROOTPATH}/usr/lib64:${DEVTOOLSET_ROOTPATH}/usr/lib:${DEVTOOLSET_ROOTPATH}/usr/lib64/dyninst:${DEVTOOLSET_ROOTPATH}/usr/lib/dyninst"
elif [ "${POLICY}" == "musllinux_1_2" ]; then
	BASEIMAGE="alpine:3.20"
	DEVTOOLSET_ROOTPATH=
	PREPEND_PATH=
	LD_LIBRARY_PATH_ARG=
else
	echo "Unsupported policy: '${POLICY}'"
	exit 1
fi
export BASEIMAGE
export DEVTOOLSET_ROOTPATH
export PREPEND_PATH
export LD_LIBRARY_PATH_ARG

BUILD_ARGS_COMMON=(
	"--platform=linux/${GOARCH}"
	--build-arg POLICY --build-arg PLATFORM --build-arg BASEIMAGE
	--build-arg DEVTOOLSET_ROOTPATH --build-arg PREPEND_PATH --build-arg LD_LIBRARY_PATH_ARG
	--rm -t "quay.io/pypa/${POLICY}_${PLATFORM}:${COMMIT_SHA}"
	-f docker/Dockerfile docker/
)

if [ "${CI:-}" == "true" ]; then
	# Force plain output on CI
	BUILD_ARGS_COMMON=(--progress plain "${BUILD_ARGS_COMMON[@]}")
	# Workaround issue on ppc64le
	if [ "${PLATFORM}" == "ppc64le" ] && [ "${MANYLINUX_BUILD_FRONTEND}" == "docker" ]; then
		BUILD_ARGS_COMMON=(--network host "${BUILD_ARGS_COMMON[@]}")
	fi
fi

USE_LOCAL_CACHE=0
if [ "${MANYLINUX_BUILD_FRONTEND}" == "docker" ]; then
	docker build "${BUILD_ARGS_COMMON[@]}"
elif [ "${MANYLINUX_BUILD_FRONTEND}" == "podman" ]; then
	podman build "${BUILD_ARGS_COMMON[@]}"
elif [ "${MANYLINUX_BUILD_FRONTEND}" == "docker-buildx" ]; then
	USE_LOCAL_CACHE=1
	docker buildx build \
		--load \
		"--cache-from=type=local,src=$(pwd)/.buildx-cache-${POLICY}_${PLATFORM}" \
		"--cache-to=type=local,dest=$(pwd)/.buildx-cache-staging-${POLICY}_${PLATFORM},mode=max" \
		"${BUILD_ARGS_COMMON[@]}"
else
	echo "Unsupported build frontend: '${MANYLINUX_BUILD_FRONTEND}'"
	exit 1
fi

docker run --rm -v "$(pwd)/tests:/tests:ro" "quay.io/pypa/${POLICY}_${PLATFORM}:${COMMIT_SHA}" /tests/run_tests.sh

if [ ${USE_LOCAL_CACHE} -ne 0 ]; then
	if [ -d "$(pwd)/.buildx-cache-${POLICY}_${PLATFORM}" ]; then
		rm -rf "$(pwd)/.buildx-cache-${POLICY}_${PLATFORM}"
	fi
	mv "$(pwd)/.buildx-cache-staging-${POLICY}_${PLATFORM}" "$(pwd)/.buildx-cache-${POLICY}_${PLATFORM}"
fi
