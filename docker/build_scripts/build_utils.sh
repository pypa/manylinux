#!/bin/bash
# Helper utilities for build

PYTHON_DOWNLOAD_URL=https://www.python.org/ftp/python
OPENSSL_DOWNLOAD_URL=http://www.openssl.org/source
GET_PIP_URL=https://bootstrap.pypa.io/get-pip.py


function check_var {
    if [ -z "$1" ]; then
        echo "required variable not defined"
        exit 1
    fi
}


function pyver_ge {
    # Echo 1 if first python version is greater or equal to second
    # Parameters
    #   $first (python version in major.minor.extra format)
    #   $second (python version in major.minor.extra format)
    local first=$1
    check_var $first
    local second=$2
    check_var $second
    local arr_1
    local arr_2
    IFS='.' read -ra arr_1 <<< "$first"
    IFS='.' read -ra arr_2 <<< "$second"
    if [ ${arr_1[0]} -lt ${arr_2[0]} ]; then return; fi
    if [ ${arr_1[0]} -gt ${arr_2[0]} ]; then echo 1; return; fi
    # First digit equal
    if [ ${arr_1[1]} -lt ${arr_2[1]} ]; then return; fi
    if [ ${arr_1[1]} -gt ${arr_2[1]} ]; then echo 1; return; fi
    # Second digit equal
    if [ ${arr_1[2]} -ge ${arr_2[2]} ]; then echo 1; fi
}


function do_python_build {
    local py_ver=$1
    check_var $py_ver
    mkdir -p /opt/$py_ver/lib
    LDFLAGS="-Wl,-rpath /opt/$py_ver/lib" ./configure --prefix=/opt/$py_ver --enable-shared
    make -j2
    make install
}


function build_python {
    local py_ver=$1
    check_var $py_ver
    local py_ver0="$(echo $py_ver | cut -d. -f 1)"
    local py_ver2="$(echo $py_ver | cut -d. -f 1,2)"
    check_var $PYTHON_DOWNLOAD_URL
    wget -q $PYTHON_DOWNLOAD_URL/$py_ver/Python-$py_ver.tgz
    tar -xzf Python-$py_ver.tgz
    (cd Python-$py_ver && do_python_build $py_ver)
    if [ "$py_ver0" == "3" ]; then \
        ln -s /opt/$py_ver/bin/python3 /opt/$py_ver/bin/python;
    fi;
    ln -s /opt/$py_ver/ /opt/$py_ver2
    /opt/$py_ver/bin/python get-pip.py
    /opt/$py_ver/bin/pip install wheel
    rm -rf Python-$py_ver.tgz Python-$py_ver
}


function build_pythons {
    check_var $GET_PIP_URL
    curl -LO $GET_PIP_URL
    for py_ver in $@; do
        build_python $py_ver
    done
    rm get-pip.py
}


function do_openssl_build {
    ./config no-ssl2 no-shared -fPIC --prefix=/usr/local/ssl
    make
    make install
}


function build_openssl {
    local openssl_fname=$1
    check_var $openssl_fname
    local openssl_sha256=$2
    check_var $openssl_sha256
    check_var $OPENSSL_DOWNLOAD_URL
    echo "${openssl_sha256}  ${openssl_fname}.tar.gz" > ${openssl_fname}.tar.gz.sha256
    wget $OPENSSL_DOWNLOAD_URL/${openssl_fname}.tar.gz
    sha256sum -c ${openssl_fname}.tar.gz.sha256
    tar -xzf ${openssl_fname}.tar.gz
    (cd ${openssl_fname} && do_openssl_build)
    rm -rf ${openssl_fname} ${openssl_fname}.tar.gz ${openssl_fname}.tar.gz.sha256
}
