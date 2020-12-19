case "${1-}" in
32)
    tags=( quay.io/pypa/manylinux2010_x86_64_centos6_no_vsyscall_build32:latest )
    ;;
64)
    tags=( quay.io/pypa/manylinux2010_x86_64_centos6_no_vsyscall_build64:latest )
    ;;
combined_build)
    tags=(
        quay.io/pypa/manylinux2010_x86_64_centos6_no_vsyscall_build:latest
        quay.io/pypa/manylinux2010_x86_64_centos6_no_vsyscall:latest
    )
    ;;
all)
    tags=(
        quay.io/pypa/manylinux2010_x86_64_centos6_no_vsyscall_build32:latest
        quay.io/pypa/manylinux2010_x86_64_centos6_no_vsyscall_build64:latest
        quay.io/pypa/manylinux2010_x86_64_centos6_no_vsyscall_build:latest
        quay.io/pypa/manylinux2010_x86_64_centos6_no_vsyscall:latest
    )
    ;;
*)
    echo "Usage: $0 {32|64|combined_build|all}" >&2
    exit 1
    ;;
esac
