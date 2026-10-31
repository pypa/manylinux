#!/bin/bash
# Install ca-certificate and make sure it's "up-to-date", patch if needed

# Stop at any error, show all commands
set -exuo pipefail

# Set build environment variables
MY_DIR=$(dirname "${BASH_SOURCE[0]}")

# Get build utilities
# shellcheck source-path=SCRIPTDIR
source "${MY_DIR}/build_utils.sh"

function manylinux_pkg_version {
	local PKG=$1
	case "${OS_ID_LIKE}" in
		rhel) rpm -q --qf '%|EPOCH?{%{EPOCH}:}:{}|%{VERSION}%|RELEASE?{-%{RELEASE}}:{}|' "${PKG}";;
		debian) dpkg-query -W -f='${Version}' "${PKG}";;
		alpine) apk policy "${PKG}" | sed -n '2s/^[[:space:]]*//p' | tr -d :;;
		*) exit 1;;
	esac
}

function manylinux_pkg_installed {
	local PKG=$1
	case "${OS_ID_LIKE}" in
		rhel) rpm -q "${PKG}" >/dev/null 2>&1;;
		debian) dpkg -s "${PKG}" >/dev/null 2>&1;;
		alpine) apk info -e "${PKG}" >/dev/null 2>&1;;
		*) exit 1;;
	esac
}

function manylinux_pkg_version_ge {
	local LEFT=$1
	local RIGHT=$2
	case "${OS_ID_LIKE}" in
		rhel) test "$(rpm --eval "%{lua:print(rpm.vercmp('${LEFT}','${RIGHT}'))}")" -ge 0;;
		debian) dpkg --compare-versions "${LEFT}" ge "${RIGHT}";;
		alpine) test "$(apk version -t "${LEFT}" "${RIGHT}")" != "<";;
		*) exit 1;;
	esac
}

function manylinux_pkg_update {
	case "${PACKAGE_MANAGER}" in
		yum) yum update -y "$@";;
		dnf) dnf upgrade -y "$@";;
		apt)
			DEBIAN_FRONTEND=noninteractive apt-get update -qq
			DEBIAN_FRONTEND=noninteractive apt-get install -qq -y --only-upgrade "$@"
			;;
		apk) apk upgrade --no-cache "$@";;
		*) exit 1;;
	esac
}

EOL=0
case "${AUDITWHEEL_POLICY}" in
	manylinux2014) MIN_VERSION="2023.2.60_v7.0.306-72.el7_9"; EOL=1;;
	manylinux_2_28) MIN_VERSION="2026.2.92_v9.0.319-81.3.el8_10";;
	manylinux_2_31) MIN_VERSION="20240203~20.04.1"; EOL=1;;
	manylinux_2_34) MIN_VERSION="2026.2.92_v9.0.319-90.3.el9_8";;
	manylinux_2_35) MIN_VERSION="20260816ubuntu0.22.04.1";;
	manylinux_2_39) MIN_VERSION="2026.2.92_v9.0.319-100.3.el10_2";;
	musllinux_1_2) MIN_VERSION="20261020-r0";;
esac

if ! manylinux_pkg_installed ca-certificates; then
	manylinux_pkg_install ca-certificates
	manylinux_pkg_clean
else
	CURRENT_VERSION=$(manylinux_pkg_version ca-certificates)
	if ! manylinux_pkg_version_ge "${CURRENT_VERSION}" "${MIN_VERSION}"; then
		manylinux_pkg_update ca-certificates
		manylinux_pkg_clean
	fi
fi

CURRENT_VERSION=$(manylinux_pkg_version ca-certificates)
if [ ${EOL} -eq 0 ]; then
	if manylinux_pkg_version_ge "${CURRENT_VERSION}" "${MIN_VERSION}"; then
		exit 0
	fi
	exit 1
fi

# EOL distributions
# extract all certificates from the bundle
mkdir /opt/_internal/certs
mkdir /tmp/certify
csplit -z -n 4 -f /tmp/certify/certifi- "${SSL_CERT_FILE}" '/-----END CERTIFICATE-----/+1' '{*}'
# rename the files with .crt suffix
for FILE in /tmp/certify/certifi-*; do
	cp "${FILE}" "/opt/_internal/certs/$(basename "${FILE}").crt"
done
rm -rf /tmp/certify

"${MY_DIR}/patch-ca-certificates.sh"
