#!/bin/bash

# Stop at any error, show all commands
set -exuo pipefail

if [ "${AUDITWHEEL_ARCH}" != "x86_64" ]; then
	exit 0
fi

if ! echo | gcc -S -x c -o /dev/null -v - 2>&1 | grep 'march=x86-64-v' > /dev/null; then
	exit 0
fi

# Get script directory
MY_DIR=$(dirname "${BASH_SOURCE[0]}")

# Get build utilities
# shellcheck source-path=SCRIPTDIR
source "${MY_DIR}/build_utils.sh"

# create wrapper to override default -march=x86-64-v? and replace it with -march=x86-64
cat <<EOF > /tmp/manylinux-gcc-wrapper.c
#define _GNU_SOURCE
#include <limits.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

int main(int argc, char* argv[]) {
	int has_march = 0;
	int has_mtune = 0;
	for (int i = 1; i < argc; ++i) {
		if (!has_march && (strncmp(argv[i], "-march=", 7) == 0)) {
			has_march = 1;
			if (has_mtune) break;
		}
		else if (!has_mtune && (strncmp(argv[i], "-mtune=", 7) == 0)) {
			has_mtune = 1;
			if (has_march) break;
		}
	}
	int insert = 0;
  if (!has_march) {
		insert += 1;
		if (!has_mtune) insert += 1;
	}
	if (argc > (INT_MAX - insert - 1)) {
		fputs("too many arguments\n", stderr);
		return EXIT_FAILURE;
	}
	size_t argc_ = argc + insert + 1;
	if (argc_ > SIZE_MAX / sizeof(char*)) {
		fputs("too many arguments2\n", stderr);
		return EXIT_FAILURE;
	}
	char** argv_ = malloc(argc_ * sizeof(char*));
	if (argv_ == NULL) {
		fputs("can't allocate memory for arguments\n", stderr);
		return EXIT_FAILURE;
	}
	char* progname = basename(argv[0]);
	char argv0[128];
	int len = snprintf(argv0, sizeof(argv0), "${DEVTOOLSET_ROOTPATH}/usr/bin/%s", progname);
	if ((len <= 0) || (len >= sizeof(argv0))) {
		fputs("can't compute argv0\n", stderr);
		return EXIT_FAILURE;
	}
	argv_[0] = argv0;
	if (insert > 0) {
		if (insert == 2) argv_[1] = "-mtune=generic";
		argv_[insert] = "-march=x86-64";
	}
	for (int i = 1; i < argc; ++i) {
		argv_[i + insert] = argv[i];
	}
	argv_[argc_ - 1] = NULL;
	if (execv(argv0, argv_) == -1) {
		fprintf(stderr, "failed to start '%s'\n", argv0);
		return EXIT_FAILURE;
	}
	return 0;
}
EOF

# shellcheck disable=SC2086
gcc ${MANYLINUX_CFLAGS} -std=c11 -Os -s -Werror -o /usr/local/bin/manylinux-gcc-wrapper /tmp/manylinux-gcc-wrapper.c

for EXE in "${DEVTOOLSET_ROOTPATH}"/usr/bin/*; do
	if diff -q "${EXE}" "${DEVTOOLSET_ROOTPATH}/usr/bin/gcc"; then
		LINK_NAME=/usr/local/bin/$(basename "${EXE}")
		ln -s manylinux-gcc-wrapper "${LINK_NAME}"
		if echo | "${LINK_NAME}" -S -x c -o /dev/null -v - 2>&1 | grep 'march=x86-64-v' > /dev/null; then
			exit 1
		fi
	elif diff -q "${EXE}" "${DEVTOOLSET_ROOTPATH}/usr/bin/g++"; then
		LINK_NAME=/usr/local/bin/$(basename "${EXE}")
		ln -s manylinux-gcc-wrapper "${LINK_NAME}"
		if echo | "${LINK_NAME}" -S -x c++ -o /dev/null -v - 2>&1 | grep 'march=x86-64-v' > /dev/null; then
			exit 1
		fi
	elif diff -q "${EXE}" "${DEVTOOLSET_ROOTPATH}/usr/bin/gfortran"; then
		LINK_NAME=/usr/local/bin/$(basename "${EXE}")
		ln -s manylinux-gcc-wrapper "${LINK_NAME}"
		if echo | "${LINK_NAME}" -S -x f77 -o /dev/null -v - 2>&1 | grep 'march=x86-64-v' > /dev/null; then
			exit 1
		fi
	fi
done
