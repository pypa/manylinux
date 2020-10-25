#!/bin/bash
# Helper utilities for build


function check_var {
	if [ -z "$1" ]; then
		echo "required variable not defined"
		exit 1
	fi
}


function fetch_source {
	# This is called both inside and outside the build context (e.g. in Travis) to prefetch
	# source tarballs, where curl exists (and works)
	local file=$1
	check_var ${file}
	local url=$2
	check_var ${url}
	if [ -f ${file} ]; then
		echo "${file} exists, skipping fetch"
	else
		curl -fsSL -o ${file} ${url}/${file}
	fi
}


function check_sha256sum {
	local fname=$1
	check_var ${fname}
	local sha256=$2
	check_var ${sha256}

	echo "${sha256}  ${fname}" > ${fname}.sha256
	sha256sum -c ${fname}.sha256
	rm -f ${fname}.sha256
}


function do_standard_install {
	./configure "$@" > /dev/null
	make -j$(nproc) > /dev/null
	make -j$(nproc) install-strip > /dev/null
}


function clean_pyc {
	find $1 -type f -a \( -name '*.pyc' -o -name '*.pyo' \) -delete
}


function strip_ {
	# Strip what we can -- and ignore errors, because this just attempts to strip
	# *everything*, including non-ELF files:
	find $1 -type f -print0 | xargs -0 -n1 strip --strip-unneeded 2>/dev/null || true
}
