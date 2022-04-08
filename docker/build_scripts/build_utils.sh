#!/bin/bash
# Helper utilities for build


# use all flags used by ubuntu 20.04 for hardening builds, dpkg-buildflags --export
# other flags mentioned in https://wiki.ubuntu.com/ToolChain/CompilerFlags can't be
# used because the distros used here are too old
MANYLINUX_CPPFLAGS="-Wdate-time -D_FORTIFY_SOURCE=2"
MANYLINUX_CFLAGS="-g -O2 -Wall -fdebug-prefix-map=/=. -fstack-protector-strong -Wformat -Werror=format-security"
MANYLINUX_CXXFLAGS="-g -O2 -Wall -fdebug-prefix-map=/=. -fstack-protector-strong -Wformat -Werror=format-security"
MANYLINUX_LDFLAGS="-Wl,-Bsymbolic-functions -Wl,-z,relro -Wl,-z,now"

export BASE_POLICY=manylinux
if [ "${AUDITWHEEL_POLICY:0:9}" == "musllinux" ]; then
	export BASE_POLICY=musllinux
fi

function check_var {
    if [ -z "$1" ]; then
        echo "required variable not defined"
        exit 1
    fi
}


function lex_pyver {
    # Echoes Python version string padded with zeros
    # Thus:
    # 3.2.1 -> 003002001
    # 3     -> 003000000
    echo $1 | awk -F "." '{printf "%03d%03d%03d", $1, $2, $3}'
}


function pyver_dist_dir {
    # Echoes the dist directory name of given pyver, removing alpha/beta prerelease
    # Thus:
    # 3.2.1   -> 3.2.1
    # 3.7.0b4 -> 3.7.0
    echo $1 | awk -F "." '{printf "%d.%d.%d", $1, $2, $3}'
}


function do_cpython_build {
    local py_ver=$1
    check_var $py_ver
    local ucs_setting=$2
    check_var $ucs_setting
    tar -xzf Python-$py_ver.tgz
    pushd Python-$py_ver
    if [ "$ucs_setting" = "none" ]; then
        unicode_flags=""
        dir_suffix=""
    else
        local unicode_flags="--enable-unicode=$ucs_setting"
        local dir_suffix="-$ucs_setting"
    fi
    local prefix="/opt/_internal/cpython-${py_ver}${dir_suffix}"
    mkdir -p ${prefix}/lib
	export LD_LIBRARY_PATH=${prefix}/lib:$LD_LIBRARY_PATH
    ./configure --prefix=${prefix} --enable-shared $unicode_flags > /dev/null
    make -j2 > /dev/null
    make install > /dev/null
    popd
    rm -rf Python-$py_ver
    # Some python's install as bin/python3. Make them available as
    # bin/python.
    if [ -e ${prefix}/bin/python3 ]; then
        ln -s python3 ${prefix}/bin/python
    fi
    ${prefix}/bin/python -m ensurepip

    if [ -e ${prefix}/bin/pip3 ] && [ ! -e ${prefix}/bin/pip ]; then
        ln -s pip3 ${prefix}/bin/pip
    fi
    # Since we fall back on a canned copy of pip, we might not have
    # the latest pip and friends. Upgrade them to make sure.
    ${prefix}/bin/pip install -U --require-hashes -r ${MY_DIR}/requirements.txt
    local abi_tag=$(${prefix}/bin/python ${MY_DIR}/python-tag-abi-tag.py)
    ln -s ${prefix} /opt/python/${abi_tag}
}


function build_cpython {
    local py_ver=$1
    check_var $py_ver
    check_var $PYTHON_DOWNLOAD_URL
    local py_dist_dir=$(pyver_dist_dir $py_ver)
    curl -fsSLO $PYTHON_DOWNLOAD_URL/$py_dist_dir/Python-$py_ver.tgz
    curl -fsSLO $PYTHON_DOWNLOAD_URL/$py_dist_dir/Python-$py_ver.tgz.asc
    gpg --verify Python-$py_ver.tgz.asc
    if [ $(lex_pyver $py_ver) -lt $(lex_pyver 3.3) ]; then
        do_cpython_build $py_ver ucs2
        do_cpython_build $py_ver ucs4
    else
        do_cpython_build $py_ver none
    fi
    rm -f Python-$py_ver.tgz
    rm -f Python-$py_ver.tgz.asc
}


function build_cpythons {
    # Import public keys used to verify downloaded Python source tarballs.
    # https://www.python.org/static/files/pubkeys.txt
    gpg --import ${MY_DIR}/cpython-pubkeys.txt
    # Add version 3.8, 3.9 release manager's key
    gpg --import ${MY_DIR}/ambv-pubkey.txt
    for py_ver in $@; do
        build_cpython $py_ver
    done
    # Remove GPG hidden directory.
    rm -rf /root/.gnupg/
}


function do_openssl_build {
    ./config no-shared -fPIC --prefix=/usr/local/ssl > /dev/null
    make > /dev/null
    make install_sw > /dev/null
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
    ./configure "$@" CPPFLAGS="${MANYLINUX_CPPFLAGS}" CFLAGS="${MANYLINUX_CFLAGS}" "CXXFLAGS=${MANYLINUX_CXXFLAGS}" LDFLAGS="${MANYLINUX_LDFLAGS}" > /dev/null
    make > /dev/null
    make install > /dev/null
}

function strip_ {
	# Strip what we can -- and ignore errors, because this just attempts to strip
	# *everything*, including non-ELF files:
	find $1 -type f -print0 | xargs -0 -n1 strip --strip-unneeded 2>/dev/null || true
}

function clean_pyc {
	find $1 -type f -a \( -name '*.pyc' -o -name '*.pyo' \) -delete
}
