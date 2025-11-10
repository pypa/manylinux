#!/bin/bash

set -euo pipefail

IMAGES=(manylinux2014 manylinux_2_28 manylinux_2_31 manylinux_2_34 manylinux_2_35 manylinux_2_39 musllinux_1_2)

podman login -u "${QUAY_USERNAME}" -p "${QUAY_PASSWORD}" quay.io

for IMAGE in "${IMAGES[@]}"; do
	echo "::group::${IMAGE} check"
	LAST_TAG="$(oras repo tags --last "2025.11.08-2" "quay.io/pypa/${IMAGE}" | tail -2 | head -1)"
	if [ "${LAST_TAG}" == "" ]; then
		 LAST_TAG=2025.11.08-2
	fi
	echo "last tag is ${LAST_TAG}"
	case ${IMAGE} in
		manylinux_2_31) REF_IMAGE=manylinux_2_31_armv7l;;
		manylinux_2_35) REF_IMAGE=manylinux_2_35_armv7l;;
		manylinux_2_39) REF_IMAGE=manylinux_2_39_aarch64;;
		*) REF_IMAGE=${IMAGE}_x86_64;;
	esac
	TAGS_TO_PUSH=()
	while IFS='' read -r LINE; do
		TAGS_TO_PUSH+=("$LINE");
	done < <(oras repo tags --last "${LAST_TAG}" "quay.io/pypa/${REF_IMAGE}" | grep -v "^20[0-9][0-9]-" | grep -v "latest")
	if [ ${#TAGS_TO_PUSH[@]} -eq 0 ]; then
		echo "no new tags to push"
		echo "::endgroup::"
		continue
	fi
	echo "pushing tags ${TAGS_TO_PUSH[*]}"
	# no nested groups in GHA
	echo "::endgroup::"

	case ${IMAGE} in
		manylinux_2_31) ARCHS=("armv7l");;
		manylinux_2_35) ARCHS=("armv7l");;
		manylinux_2_39) ARCHS=("aarch64" "riscv64");;
		musllinux_1_2) ARCHS=("x86_64" "i686" "aarch64" "armv7l" "ppc64le" "s390x" "riscv64");;
		*) ARCHS=("x86_64" "i686" "aarch64" "ppc64le" "s390x");;
	esac

	LATEST_MANIFEST=
	for TAG_TO_PUSH in "${TAGS_TO_PUSH[@]}"; do
		echo "::group::${IMAGE}:${TAG_TO_PUSH}"
		SRC_IMAGES=()
		for ARCH in "${ARCHS[@]}"; do
				SRC_IMAGES+=("docker://quay.io/pypa/${IMAGE}_${ARCH}:${TAG_TO_PUSH}")
		done
		MANIFEST="${IMAGE}:${TAG_TO_PUSH}"
		if ! podman manifest create "${MANIFEST}" "${SRC_IMAGES[@]}"; then
			echo "::error ::failed to create '${MANIFEST}' manifest using ${SRC_IMAGES[*]}"
		else
			if ! podman manifest push --all "${MANIFEST}" "docker://quay.io/pypa/${IMAGE}:${TAG_TO_PUSH}"; then
				echo "::error ::failed to push 'quay.io/pypa/${IMAGE}:${TAG_TO_PUSH}' using '${MANIFEST}'"
			else
				LATEST_MANIFEST="${MANIFEST}"
			fi
		fi
		echo "::endgroup::"
	done

	echo "::group::${IMAGE}:latest"
	if [ "${LATEST_MANIFEST}" == "" ]; then
		echo "::warning ::${IMAGE}: skipping latest due to previous errors"
	else
		if ! podman manifest push --all "${LATEST_MANIFEST}" "docker://quay.io/pypa/${IMAGE}:latest"; then
			echo "::error ::failed to push 'quay.io/pypa/${IMAGE}:latest' using '${LATEST_MANIFEST}'"
		fi
	fi
	echo "::endgroup::"
done
