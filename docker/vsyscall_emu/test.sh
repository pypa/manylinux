#!/bin/bash
#
# Test vsyscall_trace, either on a docker image if a name is provided or
# directly on the host otherwise.

set -e

if [ "${PLATFORM:-$(uname -m)}" != x86_64 ]; then
    exit 0
fi

# Get build utilities
cd "$(dirname "${BASH_SOURCE[0]}")"
source ../build_scripts/build_utils.sh

set -x

# Run the kernel vsyscall test command with a fake vsyscall page
# address, so that we're guaranteed that the host kernel will segfault
# on the attempted vsyscalls.
curl -sSLO https://github.com/torvalds/linux/raw/v4.15/tools/testing/selftests/x86/test_vsyscall.c
check_sha256sum test_vsyscall.c ff55a0c8ae2fc03a248a7fa1c47ba00bfe73abcef09606b6708e01f246a4f2b5
echo 'fffffffffe600000-fffffffffe601000 --xp 00000000 00:00 0                  [vsyscall]' > maps
sed -i -e 's/0xffffffffff6/0xfffffffffe6/' -e 's|/proc/self/maps|/proc/self/cwd/maps|' test_vsyscall.c
cc -ggdb3 -o test_vsyscall test_vsyscall.c -ldl

if [ -n "$1" ]; then
    docker run -v "$PWD":/vsyscall_emu --rm --entrypoint /vsyscall_emu/vsyscall_trace_test --security-opt=seccomp:unconfined --workdir /vsyscall_emu "$1" ./test_vsyscall
else
    ./vsyscall_trace_test ./test_vsyscall
fi

rm -f test_vsyscall test_vsyscall.c maps
