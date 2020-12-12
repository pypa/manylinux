case "${1-}" in
32)
    tags=( quay.io/pypa/manylinux2010_centos-6-with-vsyscall32:latest )
    ;;
64)
    tags=( quay.io/pypa/manylinux2010_centos-6-with-vsyscall64:latest )
    ;;
combined_build)
    tags=(
        quay.io/pypa/manylinux2010_centos-6-no-vsyscall-build:latest
        quay.io/pypa/manylinux2010_centos-6-no-vsyscall:latest
    )
    ;;
combined)
    tags=( quay.io/pypa/manylinux2010_centos-6-no-vsyscall:latest )
    ;;
all)
    tags=(
        quay.io/pypa/manylinux2010_centos-6-with-vsyscall32:latest
        quay.io/pypa/manylinux2010_centos-6-with-vsyscall64:latest
        quay.io/pypa/manylinux2010_centos-6-no-vsyscall-build:latest
        quay.io/pypa/manylinux2010_centos-6-no-vsyscall:latest
    )
    ;;
*)
    echo "Usage: $0 {32|64|combined_build|combined|all}" >&2
    exit 1
    ;;
esac
