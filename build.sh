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
	riscv64) GOARCH="riscv64";;
	*) echo "Unsupported platform: '${PLATFORM}'"; exit 1;;
esac

# setup BASEIMAGE and its specific properties
if [ "${POLICY}" == "manylinux2014" ]; then
	BASEIMAGE="quay.io/pypa/manylinux2014_base:2025.11.10-3"
	DEVTOOLSET_ROOTPATH="/opt/rh/devtoolset-10/root"
	PREPEND_PATH="${DEVTOOLSET_ROOTPATH}/usr/bin:"
	if [ "${PLATFORM}" == "i686" ]; then
		LD_LIBRARY_PATH_ARG="${DEVTOOLSET_ROOTPATH}/usr/lib:${DEVTOOLSET_ROOTPATH}/usr/lib/dyninst"
	else
		LD_LIBRARY_PATH_ARG="${DEVTOOLSET_ROOTPATH}/usr/lib64:${DEVTOOLSET_ROOTPATH}/usr/lib:${DEVTOOLSET_ROOTPATH}/usr/lib64/dyninst:${DEVTOOLSET_ROOTPATH}/usr/lib/dyninst:/usr/local/lib64"
	fi
elif [ "${POLICY}" == "manylinux_2_28" ]; then
	BASEIMAGE="quay.io/almalinuxorg/almalinux:8"
	DEVTOOLSET_ROOTPATH="/opt/rh/gcc-toolset-15/root"
	PREPEND_PATH="${DEVTOOLSET_ROOTPATH}/usr/bin:"
	LD_LIBRARY_PATH_ARG="${DEVTOOLSET_ROOTPATH}/usr/lib64:${DEVTOOLSET_ROOTPATH}/usr/lib:${DEVTOOLSET_ROOTPATH}/usr/lib64/dyninst:${DEVTOOLSET_ROOTPATH}/usr/lib/dyninst"
elif [ "${POLICY}" == "manylinux_2_31" ]; then
	BASEIMAGE="ubuntu:20.04"
	DEVTOOLSET_ROOTPATH=
	PREPEND_PATH=
	LD_LIBRARY_PATH_ARG=
elif [ "${POLICY}" == "manylinux_2_34" ]; then
	BASEIMAGE="quay.io/almalinuxorg/almalinux:9"
	DEVTOOLSET_ROOTPATH="/opt/rh/gcc-toolset-15/root"
	PREPEND_PATH="/usr/local/bin:${DEVTOOLSET_ROOTPATH}/usr/bin:"
	LD_LIBRARY_PATH_ARG="${DEVTOOLSET_ROOTPATH}/usr/lib64:${DEVTOOLSET_ROOTPATH}/usr/lib:${DEVTOOLSET_ROOTPATH}/usr/lib64/dyninst:${DEVTOOLSET_ROOTPATH}/usr/lib/dyninst"
elif [ "${POLICY}" == "manylinux_2_35" ]; then
	BASEIMAGE="ubuntu:22.04"
	DEVTOOLSET_ROOTPATH=
	PREPEND_PATH=
	LD_LIBRARY_PATH_ARG=
elif [ "${POLICY}" == "manylinux_2_39" ]; then
	BASEIMAGE="quay.io/almalinuxorg/almalinux:10"
	case "${PLATFORM}" in
		x86_64) GOARCH="amd64/v2";;
		riscv64) BASEIMAGE="rockylinux/rockylinux:10";;
	esac
	DEVTOOLSET_ROOTPATH="/opt/rh/gcc-toolset-15/root"
	PREPEND_PATH="/usr/local/bin:${DEVTOOLSET_ROOTPATH}/usr/bin:"
	LD_LIBRARY_PATH_ARG="${DEVTOOLSET_ROOTPATH}/usr/lib64:${DEVTOOLSET_ROOTPATH}/usr/lib:${DEVTOOLSET_ROOTPATH}/usr/lib64/dyninst:${DEVTOOLSET_ROOTPATH}/usr/lib/dyninst"
elif [ "${POLICY}" == "musllinux_1_2" ]; then
	BASEIMAGE="alpine:3.23"
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

# cross-compilation tools platform, installed in any case
if [ "${MANYLINUX_BUILDARCH:-}" == "" ]; then
	if [ "${MANYLINUX_BUILD_FRONTEND}" == "podman" ]; then
		MANYLINUX_BUILDARCH=$(podman version -f "{{.Server.Arch}}")
	else
		MANYLINUX_BUILDARCH=$(docker version -f "{{.Server.Arch}}")
	fi
	if [ "${MANYLINUX_BUILDARCH}" == "arm" ]; then
		MANYLINUX_BUILDARCH="arm/v7"
	fi
fi
export MANYLINUX_BUILDARCH

# cross-compilation tools usage, by default, only on amd64/arm64
if [ "${MANYLINUX_DISABLE_CLANG:-}" == "" ]; then
	if [ "${MANYLINUX_BUILDARCH}" == "amd64" ] || [ "${MANYLINUX_BUILDARCH}" == "arm64" ]; then
		MANYLINUX_DISABLE_CLANG=0
	else
		MANYLINUX_DISABLE_CLANG=1
	fi
fi
if [ "${MANYLINUX_DISABLE_CLANG}" != "0" ]; then
	MANYLINUX_DISABLE_CLANG=1  # integer bool like
fi
export MANYLINUX_DISABLE_CLANG

# cross-compilation tools usage when building cpython, default depends on PEP11
if [ "${MANYLINUX_DISABLE_CLANG_FOR_CPYTHON:-}" == "" ]; then
	MANYLINUX_DISABLE_CLANG_FOR_CPYTHON=0
	if [ "${POLICY:0:9}" == "manylinux" ]; then
		case "${PLATFORM}" in
			aarch64|x86_64) MANYLINUX_DISABLE_CLANG_FOR_CPYTHON=1;; # gcc is Tier-1, clang is Tier-2
			armv7l) MANYLINUX_DISABLE_CLANG_FOR_CPYTHON=1;; # gcc is Tier-3, clang not supported at all
			# s390x) MANYLINUX_DISABLE_CLANG_FOR_CPYTHON=1;; # gcc is Tier-3, clang not supported at all, gcc is too slow, use clang anyway
			*) ;;
		esac
	fi
fi
if [ "${MANYLINUX_DISABLE_CLANG_FOR_CPYTHON}" != "0" ]; then
	MANYLINUX_DISABLE_CLANG_FOR_CPYTHON=1  # integer bool like
fi
export MANYLINUX_DISABLE_CLANG_FOR_CPYTHON


MANYLINUX_IMAGE="quay.io/pypa/${POLICY}_${PLATFORM}:${COMMIT_SHA}"

BUILD_ARGS_COMMON=(
	"--platform=linux/${GOARCH}"
	"--pull=true"
	--build-arg POLICY --build-arg PLATFORM --build-arg BASEIMAGE
	--build-arg DEVTOOLSET_ROOTPATH --build-arg PREPEND_PATH --build-arg LD_LIBRARY_PATH_ARG
	--build-arg MANYLINUX_BUILDARCH --build-arg MANYLINUX_DISABLE_CLANG --build-arg MANYLINUX_DISABLE_CLANG_FOR_CPYTHON
	--rm -t "${MANYLINUX_IMAGE}"
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
TEST_COMMAND="docker"
if [ "${MANYLINUX_BUILD_FRONTEND}" == "docker" ]; then
	docker build "${BUILD_ARGS_COMMON[@]}"
elif [ "${MANYLINUX_BUILD_FRONTEND}" == "podman" ]; then
	TEST_COMMAND="podman"
	podman build "${BUILD_ARGS_COMMON[@]}"
elif [ "${MANYLINUX_BUILD_FRONTEND}" == "docker-buildx" ]; then
	if [ "${GITHUB_REPOSITORY:-}_${GITHUB_EVENT_NAME:-}_${GITHUB_REF:-}" == "pypa/manylinux_push_refs/heads/main" ]; then
		CACHE_STORE="--cache-to=type=registry,ref=ghcr.io/pypa/manylinux-cache:${POLICY}_${PLATFORM}_main,mode=max,compression=zstd,compression-level=22"
	else
		USE_LOCAL_CACHE=1
		CACHE_STORE="--cache-to=type=local,dest=$(pwd)/.buildx-cache-staging-${POLICY}_${PLATFORM},mode=max,compression=zstd,compression-level=22"
	fi
	docker buildx build \
		--load \
		"--cache-from=type=registry,ref=ghcr.io/pypa/manylinux-cache:${POLICY}_${PLATFORM}_main" \
		"--cache-from=type=local,src=$(pwd)/.buildx-cache-${POLICY}_${PLATFORM}" \
		"${CACHE_STORE}" \
		"${BUILD_ARGS_COMMON[@]}"
else
	echo "Unsupported build frontend: '${MANYLINUX_BUILD_FRONTEND}'"
	exit 1
fi

${TEST_COMMAND} run --rm "${MANYLINUX_IMAGE}" /opt/_internal/tests/run_tests.sh

if [ ${USE_LOCAL_CACHE} -ne 0 ]; then
	if [ -d "$(pwd)/.buildx-cache-${POLICY}_${PLATFORM}" ]; then
		rm -rf "$(pwd)/.buildx-cache-${POLICY}_${PLATFORM}"
	fi
	mv "$(pwd)/.buildx-cache-staging-${POLICY}_${PLATFORM}" "$(pwd)/.buildx-cache-${POLICY}_${PLATFORM}"
fi
