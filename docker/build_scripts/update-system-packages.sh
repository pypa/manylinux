#!/bin/bash
# Update system packages

# Stop at any error, show all commands
set -exuo pipefail

# Get script directory
MY_DIR=$(dirname "${BASH_SOURCE[0]}")

# Get build utilities
# shellcheck source-path=SCRIPTDIR
source "${MY_DIR}/build_utils.sh"

fixup-mirrors
if [ "${PACKAGE_MANAGER}" == "yum" ]; then
	yum -y update
	if ! localedef -V &> /dev/null; then
		# somebody messed up glibc-common package to squeeze image size, reinstall the package
		fixup-mirrors
		yum -y reinstall glibc-common
	fi
elif [ "${PACKAGE_MANAGER}" == "dnf" ]; then
	dnf -y upgrade --nobest
elif [ "${PACKAGE_MANAGER}" == "apt" ]; then
	DEBIAN_FRONTEND=noninteractive apt-get update -qq
	DEBIAN_FRONTEND=noninteractive apt-get upgrade -qq -y
elif [ "${PACKAGE_MANAGER}" == "apk" ]; then
	apk upgrade --no-cache
else
	echo "Unsupported package manager: '${PACKAGE_MANAGER}'"
	exit 1
fi
manylinux_pkg_clean
fixup-mirrors

# do we want to update locales ?
if [ "${OS_ID_LIKE}" == "rhel" ] || [ "${OS_ID_LIKE}" == "debian" ]; then
	LOCALE_ARCHIVE=/usr/lib/locale/locale-archive
	TIMESTAMP_FILE=${LOCALE_ARCHIVE}.ml.timestamp
	if [ ! -f "${TIMESTAMP_FILE}" ] || [ "${LOCALE_ARCHIVE}" -nt "${TIMESTAMP_FILE}" ]; then
		# upgrading glibc-common can end with removal on en_US.UTF-8 locale
		localedef -i en_US -f UTF-8 en_US.UTF-8

		# if we updated glibc, we need to strip locales again...
		if [ "${OS_ID_LIKE}" == "rhel" ]; then
			if localedef --list-archive | grep -sq -v -i ^en_US.utf8; then
				localedef --list-archive | grep -v -i ^en_US.utf8 | xargs localedef --delete-from-archive
			fi
			if [ "${AUDITWHEEL_POLICY}" == "manylinux2014" ]; then
				mv -f "${LOCALE_ARCHIVE}" "${LOCALE_ARCHIVE}.tmpl"
				build-locale-archive --install-langs="en_US.utf8"
			fi
		elif [ "${OS_ID_LIKE}" == "debian" ]; then
			update-locale LANG=en_US.UTF-8
		fi
		touch ${TIMESTAMP_FILE}
	fi
fi

if [ -d /usr/share/locale ]; then
	find /usr/share/locale -mindepth 1 -maxdepth 1 -not \( -name 'en*' -or -name 'locale.alias' \) -print0 | xargs -0 rm -rf
fi
if [ -d /usr/local/share/locale ]; then
	find /usr/local/share/locale -mindepth 1 -maxdepth 1 -not \( -name 'en*' -or -name 'locale.alias' \) -print0 | xargs -0 rm -rf
fi

if [ "${DEVTOOLSET_ROOTPATH:-}" != "" ]; then
	# remove useless things that have been installed/updated by devtoolset
	if [ -d "${DEVTOOLSET_ROOTPATH}/usr/share/man" ]; then
		rm -rf "${DEVTOOLSET_ROOTPATH}/usr/share/man"
	fi
	if [ -d "${DEVTOOLSET_ROOTPATH}/usr/share/locale" ]; then
		find "${DEVTOOLSET_ROOTPATH}/usr/share/locale" -mindepth 1 -maxdepth 1 -not \( -name 'en*' -or -name 'locale.alias' \) -print0 | xargs -0 rm -rf
	fi
fi

if [ -d /usr/share/backgrounds ]; then
	rm -rf /usr/share/backgrounds
fi

if [ -d /usr/local/share/man ]; then
	# https://github.com/pypa/manylinux/issues/1060
	# wrong /usr/local/man symlink
	# only delete the content
	rm -rf /usr/local/share/man/*
fi

if [ -f /usr/local/lib/libcrypt.so.1 ]; then
	# Remove libcrypt to only use installed libxcrypt instead
	find /lib* /usr/lib* \( -name 'libcrypt.a' -o -name 'libcrypt.so' -o -name 'libcrypt.so.*' -o -name 'libcrypt-2.*.so' \) -delete
fi

if [ "${BASE_POLICY}" == "musllinux" ]; then
	ldconfig /
elif [ "${BASE_POLICY}" == "manylinux" ]; then
	ldconfig
fi

# update ca certificates on EOL distribution
if [ "${AUDITWHEEL_POLICY}" == "manylinux2014" ] || [ "${AUDITWHEEL_POLICY}" == "manylinux_2_31" ]; then
	# extract all certificates from the bundle
	CERTIFI_CERT_COUNT=$(grep -c 'BEGIN CERTIFICATE' "${SSL_CERT_FILE}")
	mkdir /tmp/certify
	csplit -z -n 4 -f /tmp/certify/certifi- "${SSL_CERT_FILE}" '/-----END CERTIFICATE-----/+1' '{*}'
	if [ "${OS_ID_LIKE}" == "rhel" ]; then
		if [ -d /etc/pki/ca-trust/source/anchors ]; then
			rm -rf /etc/pki/ca-trust/source/anchors
		fi
		mkdir -p /etc/pki/ca-trust/source/anchors
		if [ -d /usr/share/pki/ca-trust-source ]; then
			rm -rf /usr/share/pki/ca-trust-source
			mkdir -p /usr/share/pki/ca-trust-source
		fi
		# rename the files with .crt suffix
		for f in /tmp/certify/certifi-*; do
			cp "$f" "/etc/pki/ca-trust/source/anchors/$(basename "$f").pem"
		done
		# update the system trust store
		update-ca-trust extract
		NEW_CERT_COUNT=$(grep -c 'BEGIN CERTIFICATE' /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem)
	elif [ "${OS_ID_LIKE}" == "debian" ]; then
		# disable all certificates in conf
		sed -i 's/^mozilla\//!mozilla\//g' /etc/ca-certificates.conf
		if [ -d /usr/local/share/ca-certificates ]; then
			rm -rf /usr/local/share/ca-certificates
		fi
		mkdir -p /usr/local/share/ca-certificates
		# rename the files with .crt suffix
		for f in /tmp/certify/certifi-*; do
			cp "$f" "/usr/local/share/ca-certificates/$(basename "$f").crt"
		done
		# update the system trust store
		update-ca-certificates --fresh
		NEW_CERT_COUNT=$(grep -c 'BEGIN CERTIFICATE' /etc/ssl/certs/ca-certificates.crt)
	fi
	if [ "${CERTIFI_CERT_COUNT}" -ne "${NEW_CERT_COUNT}" ]; then
		exit 1
	fi
	rm -rf /tmp/certify
fi
