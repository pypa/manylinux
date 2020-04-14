function pkg_fetch {
    local pkg=$1
    check_var $pkg
    local url=$2
    check_var $url
    local sha256=$3
    check_var $sha256

    cd /tmp
    wget -nv -O $pkg.tar.gz "$url"
    check_sha256sum $pkg.tar.gz $sha256
}

function pkg_enter {
    local pkg=$1
    check_var $pkg

    cd /tmp
    mkdir $pkg
    cd $pkg
    tar -x -f ../$pkg.tar.gz --strip-components=1

    current_package=$pkg
}

function pkg_leave {
    local pkg=$current_package
    check_var $pkg

    cd /tmp
    rm -rf $pkg.tar.gz $pkg

    unset current_package
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

function check_var {
    if [ -z "$1" ]; then
        echo "required variable not defined"
        exit 1
    fi
}
