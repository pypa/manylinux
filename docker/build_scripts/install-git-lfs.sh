#!/bin/bash
# Top-level build script called from Dockerfile

# Stop at any error, show all commands
set -exuo pipefail

# Get script directory
MY_DIR=$(dirname "${BASH_SOURCE[0]}")

# Get build utilities
# shellcheck source-path=SCRIPTDIR
source "${MY_DIR}/build_utils.sh"

cd /tmp
case "${AUDITWHEEL_ARCH}" in
	x86_64) GOARCH=amd64;;
	i686) GOARCH=386;;
	aarch64) GOARCH=arm64;;
	armv7l) GOARCH=arm;;
	loongarch64) GOARCH=loong64;;
	*) GOARCH="${AUDITWHEEL_ARCH}";;
esac

GIT_LFS_VERSION=3.7.1
GIT_LFS_SHA256=sha256sums.asc
GIT_LFS_ARCHIVE="git-lfs-linux-${GOARCH}-v${GIT_LFS_VERSION}.tar.gz"

# for some reason, using --homedir gpg option fails, let's backup instead
if [ -d ~/.gnupg ]; then
	mv ~/.gnupg ~/.gnupg.backup
fi

tar -Ozxf "${MY_DIR}/git-lfs-core-gpg-keys" | gpg --import -

curl -fsSL --retry 10 -o "${GIT_LFS_SHA256}" "https://github.com/git-lfs/git-lfs/releases/download/v${GIT_LFS_VERSION}/sha256sums.asc"
curl -fsSL --retry 10 -o "${GIT_LFS_ARCHIVE}" "https://github.com/git-lfs/git-lfs/releases/download/v${GIT_LFS_VERSION}/${GIT_LFS_ARCHIVE}"

gpg -d "${GIT_LFS_SHA256}" | grep "${GIT_LFS_ARCHIVE}" | sha256sum -c
if [ "${AUDITWHEEL_POLICY}" != "manylinux2014" ]; then
	gpgconf --kill gpg-agent
fi

mkdir git-lfs
tar -C git-lfs -xf "${GIT_LFS_ARCHIVE}" --strip-components 1
./git-lfs/install.sh

rm -rf ~/.gnupg
if [ -d ~/.gnupg.backup ]; then
	mv ~/.gnupg.backup ~/.gnupg
fi

rm -rf "${GIT_LFS_SHA256}" "${GIT_LFS_ARCHIVE}" ./git-lfs
